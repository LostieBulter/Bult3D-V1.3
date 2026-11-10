class_name AlphaHelper
extends RefCounted

# Texturas de este tamaño o menos (por lado) se muestran sin suavizar (pixel art)
const PIXEL_ART_MAX_SIZE := 256

# Ajusta el material según su textura: transparencia si tiene alfa
# y sin suavizado si es una imagen pequeña (pixel art)
static func fix(mat: BaseMaterial3D) -> void:
	if mat == null or mat.albedo_texture == null:
		return
	var img: Image = mat.albedo_texture.get_image()
	if img == null:
		return

	if img.detect_alpha() != Image.ALPHA_NONE:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS

	if img.get_width() <= PIXEL_ART_MAX_SIZE and img.get_height() <= PIXEL_ART_MAX_SIZE:
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
