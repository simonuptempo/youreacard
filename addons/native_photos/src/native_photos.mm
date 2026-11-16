#include "native_photos.h"

#include <godot_cpp/core/class_db.hpp>

#include <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#include <dlfcn.h>
#endif

using namespace godot;

NativePhotosIOS *NativePhotosIOS::singleton = nullptr;

#if TARGET_OS_IOS

// Shrink to at most 1280 px on the long side, bake in the orientation, and encode as JPEG.
static PackedByteArray jpeg_bytes(UIImage *image) {
	CGFloat max_side = 1280.0;
	CGSize size = image.size;
	CGFloat scale = MIN(1.0, max_side / MAX(size.width, size.height));
	CGSize target = CGSizeMake(floor(size.width * scale), floor(size.height * scale));
	UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
	format.scale = 1.0;
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target format:format];
	UIImage *drawn = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
		[image drawInRect:CGRectMake(0, 0, target.width, target.height)];
	}];
	NSData *data = UIImageJPEGRepresentation(drawn, 0.9);
	PackedByteArray out;
	out.resize((int64_t)data.length);
	memcpy(out.ptrw(), data.bytes, data.length);
	return out;
}

static UIViewController *top_controller() {
	UIWindow *window = nil;
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		for (UIWindow *w in ((UIWindowScene *)scene).windows) {
			if (w.isKeyWindow) {
				window = w;
				break;
			}
		}
		if (window == nil && ((UIWindowScene *)scene).windows.count > 0) {
			window = ((UIWindowScene *)scene).windows.firstObject;
		}
		if (window != nil) {
			break;
		}
	}
	UIViewController *vc = window.rootViewController;
	while (vc.presentedViewController != nil) {
		vc = vc.presentedViewController;
	}
	return vc;
}

static void send_image(UIImage *image) {
	NativePhotosIOS *s = NativePhotosIOS::get_singleton();
	if (s != nullptr) {
		s->deliver(jpeg_bytes(image));
	}
}

static void send_cancel() {
	NativePhotosIOS *s = NativePhotosIOS::get_singleton();
	if (s != nullptr) {
		s->report_cancel();
	}
}

static void send_failure(const char *reason) {
	NativePhotosIOS *s = NativePhotosIOS::get_singleton();
	if (s != nullptr) {
		s->report_failure(String(reason));
	}
}

@interface GemHeistPhotoDelegate : NSObject <PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end

@implementation GemHeistPhotoDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
	[picker dismissViewControllerAnimated:YES completion:nil];
	if (results.count == 0) {
		send_cancel();
		return;
	}
	NSItemProvider *provider = results.firstObject.itemProvider;
	if (![provider canLoadObjectOfClass:[UIImage class]]) {
		send_failure("That isn't a photo. Please choose another.");
		return;
	}
	[provider loadObjectOfClass:[UIImage class]
			  completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
				  UIImage *image = [object isKindOfClass:[UIImage class]] ? (UIImage *)object : nil;
				  dispatch_async(dispatch_get_main_queue(), ^{
					  if (image == nil) {
						  send_failure("Couldn't open that photo. Please try another.");
					  } else {
						  send_image(image);
					  }
				  });
			  }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	[picker dismissViewControllerAnimated:YES completion:nil];
	if (image != nil) {
		send_image(image);
	} else {
		send_cancel();
	}
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
	send_cancel();
}

@end

static GemHeistPhotoDelegate *photo_delegate = nil;

static GemHeistPhotoDelegate *get_delegate() {
	if (photo_delegate == nil) {
		photo_delegate = [[GemHeistPhotoDelegate alloc] init];
	}
	return photo_delegate;
}

#endif // TARGET_OS_IOS

void NativePhotosIOS::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_available"), &NativePhotosIOS::is_available);
	ClassDB::bind_method(D_METHOD("has_camera"), &NativePhotosIOS::has_camera);
	ClassDB::bind_method(D_METHOD("pick_photo"), &NativePhotosIOS::pick_photo);
	ClassDB::bind_method(D_METHOD("take_photo", "front"), &NativePhotosIOS::take_photo, DEFVAL(true));
	ADD_SIGNAL(MethodInfo("photo_ready", PropertyInfo(Variant::PACKED_BYTE_ARRAY, "jpeg")));
	ADD_SIGNAL(MethodInfo("photo_cancelled"));
	ADD_SIGNAL(MethodInfo("photo_failed", PropertyInfo(Variant::STRING, "reason")));
}

NativePhotosIOS *NativePhotosIOS::get_singleton() {
	return singleton;
}

NativePhotosIOS::NativePhotosIOS() {
	singleton = this;
}

NativePhotosIOS::~NativePhotosIOS() {
	if (singleton == this) {
		singleton = nullptr;
	}
}

bool NativePhotosIOS::is_available() const {
#if TARGET_OS_IOS
	return true;
#else
	return false;
#endif
}

bool NativePhotosIOS::has_camera() const {
#if TARGET_OS_IOS
	return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
#else
	return false;
#endif
}

void NativePhotosIOS::pick_photo() {
#if TARGET_OS_IOS
	// PhotosUI is loaded at run time, so the app doesn't need to link it.
	dlopen("/System/Library/Frameworks/PhotosUI.framework/PhotosUI", RTLD_LAZY);
	Class config_class = NSClassFromString(@"PHPickerConfiguration");
	Class picker_class = NSClassFromString(@"PHPickerViewController");
	Class filter_class = NSClassFromString(@"PHPickerFilter");
	if (config_class == nil || picker_class == nil || filter_class == nil) {
		report_failure("Your photo library isn't available on this device.");
		return;
	}
	PHPickerConfiguration *config = [[config_class alloc] init];
	config.filter = [filter_class imagesFilter];
	config.selectionLimit = 1;
	PHPickerViewController *picker = [[picker_class alloc] initWithConfiguration:config];
	picker.delegate = get_delegate();
	UIViewController *host = top_controller();
	if (host == nil) {
		report_failure("Couldn't open your photos. Please try again.");
		return;
	}
	[host presentViewController:picker animated:YES completion:nil];
#else
	report_failure("The photo library opens on iPhone and iPad.");
#endif
}

void NativePhotosIOS::take_photo(bool p_front) {
#if TARGET_OS_IOS
	if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
		report_failure("This device doesn't have a camera.");
		return;
	}
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypeCamera;
	UIImagePickerControllerCameraDevice wanted = p_front ? UIImagePickerControllerCameraDeviceFront : UIImagePickerControllerCameraDeviceRear;
	if ([UIImagePickerController isCameraDeviceAvailable:wanted]) {
		picker.cameraDevice = wanted;
	}
	picker.delegate = get_delegate();
	UIViewController *host = top_controller();
	if (host == nil) {
		report_failure("Couldn't open the camera. Please try again.");
		return;
	}
	[host presentViewController:picker animated:YES completion:nil];
#else
	report_failure("The camera opens on iPhone and iPad.");
#endif
}

void NativePhotosIOS::deliver(const PackedByteArray &p_jpeg) {
	call_deferred("emit_signal", "photo_ready", p_jpeg);
}

void NativePhotosIOS::report_cancel() {
	call_deferred("emit_signal", "photo_cancelled");
}

void NativePhotosIOS::report_failure(const String &p_reason) {
	call_deferred("emit_signal", "photo_failed", p_reason);
}
