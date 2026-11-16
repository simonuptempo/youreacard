#pragma once
// Native camera + photo library for iOS (Gem Heist). On other platforms every call
// just reports that it isn't available, so the game falls back to its own screens.

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class NativePhotosIOS : public Object {
	GDCLASS(NativePhotosIOS, Object);

	static NativePhotosIOS *singleton;

protected:
	static void _bind_methods();

public:
	static NativePhotosIOS *get_singleton();

	NativePhotosIOS();
	~NativePhotosIOS();

	bool is_available() const;      // true on iOS
	bool has_camera() const;
	void pick_photo();              // the system Photos picker (no permission prompt needed)
	void take_photo(bool p_front);  // the system camera; p_front starts on the selfie camera

	// Called by the native side; emit the signals on Godot's main loop.
	void deliver(const PackedByteArray &p_jpeg);
	void report_cancel();
	void report_failure(const String &p_reason);
};

} // namespace godot
