extends RefCounted
## Cached vector button art. PlayStation symbols never depend on font glyphs.
const TOKENS := {"A":JOY_BUTTON_A,"B":JOY_BUTTON_B,"X":JOY_BUTTON_X,"Y":JOY_BUTTON_Y,"LB":JOY_BUTTON_LEFT_SHOULDER,"RB":JOY_BUTTON_RIGHT_SHOULDER,"LT":104,"RT":105,"L3":JOY_BUTTON_LEFT_STICK,"R3":JOY_BUTTON_RIGHT_STICK,"START":JOY_BUTTON_START,"VIEW":JOY_BUTTON_BACK,"LS":-2,"RS":-3,"D-PAD":-4}
const LETTERS := {"A":"M0 12L4 0L8 12M2 7H6","B":"M0 0V12H4Q10 12 7 7L4 6H0M4 6Q10 6 7 1L4 0H0","X":"M0 0L8 12M8 0L0 12","Y":"M0 0L4 6L8 0M4 6V12","L":"M0 0V12H8","R":"M0 12V0H4Q10 0 7 5L4 6H0M4 6L8 12","T":"M0 0H8M4 0V12","S":"M8 1Q0 -2 0 3Q0 6 4 6Q8 6 8 9Q8 14 0 11","1":"M2 3L5 0V12M2 12H8","2":"M0 3Q0 -1 5 0Q10 1 7 5L0 12H8","3":"M0 1Q8 -2 8 3Q8 6 3 6Q8 6 8 9Q8 14 0 11"}
static var cache: Dictionary = {}

static func tokens(keys: String) -> PackedStringArray:
	return keys.replace("SOL ANALOG","LS").replace("SAĞ ANALOG","RS").split(" ",false)

static func icon(button: int,family: String) -> Texture2D:
	var key := family+str(button)
	if cache.has(key): return cache[key]
	var ps := family=="playstation"
	var face := button>=0 and button<=3
	var tint: String=["#97d3a0","#ed918c","#93bfe9","#e9ce87"][button] if face else "#e5eae4"
	if ps and face: tint=["#93bfe9","#ed918c","#efa0c6","#91d6bc"][button]
	var shape := '<circle cx="20" cy="20" r="17.8" fill="#142d35" stroke="#526c72" stroke-width="1.4"/>' if face or button in [7,8,-2,-3] else '<rect x="1.5" y="5" width="37" height="30" rx="7" fill="#142d35" stroke="#526c72" stroke-width="1.4"/>'
	var art := ""
	if face and ps:
		art=['<path d="M13 13L27 27M27 13L13 27"/>','<circle cx="20" cy="20" r="9"/>','<rect x="11.5" y="11.5" width="17" height="17" rx="0.6"/>','<path d="M20 10L30 28H10Z"/>'][button]
	elif button==JOY_BUTTON_START:
		art='<path d="M12 13H28M12 20H28M12 27H28"/>'
	elif button==JOY_BUTTON_BACK:
		art='<path d="M13 27V15L20 10M13 15L26 19"/><circle cx="20" cy="9" r="2"/><circle cx="27" cy="20" r="2"/>' if ps else '<path d="M10 11H25V23H10ZM15 17H30V29H15"/>'
	elif button==-4:
		art='<path d="M16 9H24V16H31V24H24V31H16V24H9V16H16Z"/>'
	else:
		var word: String={0:"A",1:"B",2:"X",3:"Y",7:"L3",8:"R3",9:"L1" if ps else "LB",10:"R1" if ps else "RB",104:"L2" if ps else "LT",105:"R2" if ps else "RT",-2:"L",-3:"R"}.get(button,"")
		var start := 20.0-(word.length()*11.0-3.0)*0.5
		for i in range(word.length()):
			art+='<path transform="translate(%s 14)" d="%s"/>' % [start+i*11,LETTERS[word[i]]]
		if word=="": art='<circle cx="20" cy="20" r="4"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">%s<g fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [shape,tint,art]
	var bitmap := Image.new()
	bitmap.load_svg_from_string(svg,2.0)
	var texture := ImageTexture.create_from_image(bitmap)
	cache[key]=texture
	return texture

static func width(keys: String,font: Font,height: float=28,font_size: int=13) -> float:
	var total := -5.0
	for token in tokens(keys): total+=(height if TOKENS.has(token) else font.get_string_size(token,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+5
	return maxf(total,0)

static func draw_sequence(canvas: CanvasItem,at: Vector2,keys: String,family: String,font: Font,height: float=28,font_size: int=13) -> float:
	var x := at.x
	for token in tokens(keys):
		var w: float=height if TOKENS.has(token) else font.get_string_size(token,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		if TOKENS.has(token): canvas.draw_texture_rect(icon(TOKENS[token],family),Rect2(x,at.y-height*0.5,height,height),false)
		else: canvas.draw_string(font,Vector2(x,at.y+font_size*0.35),token,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("b4c5bd"))
		x+=w+5
	return x-at.x-5

static func draw_hints(canvas: CanvasItem,at: Vector2,items: Array,family: String,font: Font,height: float=27,font_size: int=12,gap: float=24) -> float:
	var x := at.x
	for item in items:
		x+=draw_sequence(canvas,Vector2(x,at.y),item[0],family,font,height,font_size)+7
		canvas.draw_string(font,Vector2(x,at.y+font_size*0.35),item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("e5eae4"))
		x+=font.get_string_size(item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+gap
	return x-at.x-gap
