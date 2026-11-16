#include <gdextension_interface.h>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "native_photos.h"

using namespace godot;

static NativePhotosIOS *photos = nullptr;

static void initialize_native_photos(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(NativePhotosIOS);
	photos = memnew(NativePhotosIOS);
	Engine::get_singleton()->register_singleton("NativePhotos", photos);
}

static void uninitialize_native_photos(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	Engine::get_singleton()->unregister_singleton("NativePhotos");
	memdelete(photos);
	photos = nullptr;
}

extern "C" {
GDExtensionBool GDE_EXPORT native_photos_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_native_photos);
	init_obj.register_terminator(uninitialize_native_photos);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
