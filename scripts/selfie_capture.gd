extends Control
## Camera only starts after Take a selfie. Closing or capturing always releases it.
signal captured(image: Image)
var _feed: CameraFeed
var _texture: CameraTexture
var _chroma: CameraTexture
var _viewport: SubViewport
var _surface: TextureRect
var _message: Label
var _capture: Button
var _material: ShaderMaterial
var _elapsed := 0.0
var _started := false
var _has_frame := false

func _ready() -> void:
	add_child(UI.panel(Vector2.ZERO,Vector2(720,1280),UI.BG,0))
	add_child(UI.label("Take a selfie",Vector2(24,28),Vector2(672,60),34,UI.ACCENT,HORIZONTAL_ALIGNMENT_CENTER))
	_message = UI.label("Allow camera access to see your preview.",Vector2(28,100),Vector2(664,80),22,UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_message)
	_viewport=SubViewport.new()
	_viewport.size=Vector2i(600,800)
	_viewport.disable_3d=true
	_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_surface=TextureRect.new()
	_surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_surface.size=Vector2(600,800)
	_viewport.add_child(_surface)
	var preview:=TextureRect.new()
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.texture=_viewport.get_texture()
	preview.position=Vector2(60,210)
	preview.size=Vector2(600,800)
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(preview)
	_capture=UI.button("Capture photo",Vector2(248,1140),Vector2(444,72),UI.ACCENT,25)
	_capture.disabled=true
	_capture.pressed.connect(_snap)
	add_child(_capture)
	var cancel:=UI.button("Cancel",Vector2(28,1140),Vector2(204,72),UI.PANEL,24)
	cancel.pressed.connect(queue_free)
	add_child(cancel)
	var flip:=UI.button("Switch camera",Vector2(190,1030),Vector2(340,60),UI.PANEL,22)
	flip.pressed.connect(_switch_camera)
	add_child(flip)
	if OS.get_name()=="Android" and not "android.permission.CAMERA" in OS.get_granted_permissions():
		get_tree().on_request_permissions_result.connect(_permission_result)
		OS.request_permission("android.permission.CAMERA")
	else:
		_start()

func _permission_result(permission: String, granted: bool) -> void:
	if permission != "android.permission.CAMERA": return
	if granted: _start()
	else: _message.text="Camera access was declined. Go back and upload a photo instead."

func _start() -> void:
	_started=true
	CameraServer.monitoring_feeds=true
	CameraServer.camera_feeds_updated.connect(_find_camera)
	_find_camera()

func _find_camera() -> void:
	if _feed != null: return
	var feeds:=CameraServer.feeds()
	if feeds.is_empty(): return
	var choice: CameraFeed=feeds[0]
	for feed in feeds:
		if feed.get_position()==CameraFeed.FEED_FRONT: choice=feed
	_use_feed(choice)

func _use_feed(feed: CameraFeed) -> void:
	if _feed != null: _feed.feed_is_active=false
	_feed=feed
	_has_frame=false
	_elapsed=0.0
	_capture.disabled=true
	if not _feed.formats.is_empty(): _feed.set_format(0,{})
	_texture=CameraTexture.new()
	_texture.camera_feed_id=feed.get_id()
	_texture.which_feed=CameraServer.FEED_RGBA_IMAGE
	_chroma=CameraTexture.new()
	_chroma.camera_feed_id=feed.get_id()
	_chroma.which_feed=CameraServer.FEED_CBCR_IMAGE
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform sampler2D chroma;
uniform int format=1;
uniform vec2 axis_x=vec2(1.,0.);
uniform vec2 axis_y=vec2(0.,1.);
uniform vec2 origin=vec2(0.);
void fragment(){
 vec2 uv=origin+axis_x*UV.x+axis_y*UV.y;
 vec4 pixel=texture(TEXTURE,uv);
 if(format==2 || format==3){
  vec2 cbcr=(format==3?texture(chroma,uv).rg:pixel.gb)-vec2(.5);
  float y=pixel.r;
  pixel=vec4(y+1.402*cbcr.y,y-.344136*cbcr.x-.714136*cbcr.y,y+1.772*cbcr.x,1.);
 }
 COLOR=pixel;
}"""
	_material=ShaderMaterial.new()
	_material.shader=shader
	_material.set_shader_parameter("chroma",_chroma)
	_surface.material=_material
	_surface.texture=_texture
	_feed.feed_is_active=true

func _process(delta: float) -> void:
	if not _started: return
	_elapsed+=delta
	if _feed != null and _texture != null and _texture.get_width()>0 and _feed.get_datatype()!=CameraFeed.FEED_NOIMAGE:
		_material.set_shader_parameter("format",_feed.get_datatype())
		var transform:=_feed.feed_transform
		_material.set_shader_parameter("axis_x",transform.x)
		_material.set_shader_parameter("axis_y",transform.y)
		_material.set_shader_parameter("origin",transform.origin)
		var dimensions:=Vector2i(_texture.get_size())
		if absf(transform.x.y) > 0.5: dimensions = Vector2i(dimensions.y, dimensions.x)
		if dimensions.x>0 and dimensions.y>0:
			_viewport.size=dimensions
			_surface.size=Vector2(dimensions)
		_has_frame=true
		_capture.disabled=false
		_message.text="Frame your face, then capture. You can crop it next."
	elif _elapsed>8:
		_message.text="Camera unavailable. Check camera permission, or go back and upload a photo."

func _switch_camera() -> void:
	var feeds:=CameraServer.feeds()
	if feeds.size()<2: return
	var index:=feeds.find(_feed)
	_use_feed(feeds[(index+1)%feeds.size()])

func _snap() -> void:
	if not _has_frame: return
	await RenderingServer.frame_post_draw
	var image:=_viewport.get_texture().get_image()
	if image==null or image.is_empty(): return
	captured.emit(image)
	queue_free()

func _exit_tree() -> void:
	if _feed!=null: _feed.feed_is_active=false
	if _started: CameraServer.monitoring_feeds=false
