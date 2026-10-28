# Modelo de exportação Web enxuto (spec 012, RF92), compilado no CI
# (.github/workflows/build.yml, job web-template) com:
#   scons platform=web target=template_release profile=tools/web_template/custom.py
# (platform e target têm que ir na linha de comando: o perfil é lido depois)
# Mudar este arquivo invalida o cache e recompila o modelo (~10 min no CI).
#
# Só o que o jogo usa em execução: GDScript, fontes TTF (freetype + servidor
# de texto simples — pt/en/es não precisam do avançado), WebP (artes de
# título com perda), SVG (ícones do tema padrão, ex.: alça do slider) e
# mbedtls (código aleatório do aparelho no ranking). Sem 3D, física,
# navegação, áudio OGG/MP3, rede além do HTTPRequest, nem importadores.
threads = "no"
production = "yes"
optimize = "size_extra"
disable_3d = "yes"
modules_enabled_by_default = "no"
module_gdscript_enabled = "yes"
module_freetype_enabled = "yes"
module_text_server_fb_enabled = "yes"
module_webp_enabled = "yes"
module_svg_enabled = "yes"
module_mbedtls_enabled = "yes"
