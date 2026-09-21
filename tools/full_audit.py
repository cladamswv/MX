#!/usr/bin/env python3
from pathlib import Path
import re, struct, json, wave, sys, zipfile

ROOT = Path(__file__).resolve().parents[1]
errors = []
warnings = []

required = [
    'project.godot','export_presets.cfg','Main.tscn',
    'scripts/Main.gd','scripts/Bike.gd','scripts/HUD.gd','scripts/TrackBuilder.gd',
    'scripts/AudioManager.gd','scripts/CameraRig.gd','scripts/SmokeTest.gd',
    '.github/workflows/android.yml',
    'models/dirt_bike_rider_arcade_v4.glb',
    'models/props/background_pine_ridge_mp.glb',
    'models/props/background_red_mesa_mp.glb',
    'models/props/background_quarry_mp.glb',
    'ui/logo_main.png','ui/logo_mark.png','ui/menu_background.jpg','ui/loading_background.jpg',
    'audio/engine/engine_idle.wav','audio/engine/engine_mid.wav','audio/engine/engine_high.wav',
]
for rel in required:
    if not (ROOT/rel).is_file():
        errors.append(f'MISSING REQUIRED FILE: {rel}')

# Verify every res:// reference in code/config exists.
code_exts={'.gd','.tscn','.godot','.cfg','.yml','.yaml'}
resource_refs=0
for p in ROOT.rglob('*'):
    if not p.is_file() or p.suffix.lower() not in code_exts:
        continue
    text=p.read_text('utf-8',errors='ignore')
    for ref in re.findall(r'res://[^"\'\)\]\s,]+', text):
        resource_refs += 1
        target=ROOT/ref[6:]
        if not target.exists():
            errors.append(f'MISSING RESOURCE: {ref} referenced by {p.relative_to(ROOT)}')

# Input map coverage.
project=(ROOT/'project.godot').read_text('utf-8')
defined=set(re.findall(r'^([A-Za-z0-9_]+)=\{', project, flags=re.M))
used=set()
for p in (ROOT/'scripts').glob('*.gd'):
    t=p.read_text('utf-8')
    used.update(re.findall(r'Input\.(?:is_action_pressed|is_action_just_pressed|get_action_strength)\("([^"]+)"\)', t))
for action in sorted(used-defined):
    errors.append(f'INPUT ACTION USED BUT NOT DEFINED: {action}')

# Minimal GDScript structural sanity: no tabs, no conflict markers, balanced delimiters outside strings/comments.
def strip_strings_comments(text: str) -> str:
    out=[]; i=0; quote=None; esc=False
    while i < len(text):
        c=text[i]
        if quote:
            if esc:
                esc=False
            elif c=='\\':
                esc=True
            elif c==quote:
                quote=None
            out.append(' ')
            i+=1; continue
        if c in ('"', "'"):
            quote=c; out.append(' '); i+=1; continue
        if c=='#':
            while i < len(text) and text[i] != '\n':
                out.append(' '); i+=1
            continue
        out.append(c); i+=1
    return ''.join(out)

for p in sorted((ROOT/'scripts').glob('*.gd')):
    text=p.read_text('utf-8')
    if '\t' in text:
        errors.append(f'TAB INDENTATION FOUND: {p.relative_to(ROOT)}')
    if any(m in text for m in ('<<<<<<<','=======\n','>>>>>>>')):
        errors.append(f'MERGE CONFLICT MARKER FOUND: {p.relative_to(ROOT)}')
    clean=strip_strings_comments(text)
    pairs={')':'(',']':'[','}':'{'}; stack=[]
    for idx,c in enumerate(clean):
        if c in '([{': stack.append((c,idx))
        elif c in ')]}':
            if not stack or stack[-1][0] != pairs[c]:
                errors.append(f'UNBALANCED DELIMITER {c}: {p.relative_to(ROOT)}')
                break
            stack.pop()
    if stack:
        errors.append(f'UNCLOSED DELIMITER {stack[-1][0]}: {p.relative_to(ROOT)}')

# GLB container validation.
glb_count=0
for p in ROOT.rglob('*.glb'):
    glb_count += 1
    b=p.read_bytes()
    if len(b)<20 or b[:4] != b'glTF':
        errors.append(f'INVALID GLB HEADER: {p.relative_to(ROOT)}'); continue
    version,total=struct.unpack_from('<II', b, 4)
    if version != 2 or total != len(b):
        errors.append(f'INVALID GLB LENGTH/VERSION: {p.relative_to(ROOT)}'); continue
    off=12; json_ok=False
    while off+8 <= len(b):
        length,ctype=struct.unpack_from('<II',b,off); off+=8
        if off+length > len(b):
            errors.append(f'GLB CHUNK OVERRUN: {p.relative_to(ROOT)}'); break
        chunk=b[off:off+length]; off+=length
        if ctype == 0x4E4F534A:
            try:
                json.loads(chunk.decode('utf-8').rstrip('\x00 ').strip()); json_ok=True
            except Exception as exc:
                errors.append(f'GLB JSON ERROR: {p.relative_to(ROOT)}: {exc}')
    if not json_ok:
        errors.append(f'GLB JSON CHUNK MISSING: {p.relative_to(ROOT)}')

# Images.
image_count=0
for p in ROOT.rglob('*'):
    if not p.is_file() or p.suffix.lower() not in {'.png','.jpg','.jpeg'}: continue
    image_count += 1
    b=p.read_bytes()[:16]
    if p.suffix.lower()=='.png' and not b.startswith(b'\x89PNG\r\n\x1a\n'):
        errors.append(f'INVALID PNG: {p.relative_to(ROOT)}')
    if p.suffix.lower() in {'.jpg','.jpeg'} and not b.startswith(b'\xff\xd8'):
        errors.append(f'INVALID JPEG: {p.relative_to(ROOT)}')

# Audio.
wav_count=0
for p in ROOT.rglob('*.wav'):
    wav_count += 1
    try:
        with wave.open(str(p),'rb') as w:
            if w.getnframes() <= 0 or w.getframerate() <= 0:
                errors.append(f'EMPTY WAV: {p.relative_to(ROOT)}')
    except Exception as exc:
        errors.append(f'INVALID WAV: {p.relative_to(ROOT)}: {exc}')
ogg_count=0
for p in ROOT.rglob('*.ogg'):
    ogg_count += 1
    if p.read_bytes()[:4] != b'OggS':
        errors.append(f'INVALID OGG: {p.relative_to(ROOT)}')

# Version / Android metadata.
export=(ROOT/'export_presets.cfg').read_text('utf-8')
workflow=(ROOT/'.github/workflows/android.yml').read_text('utf-8')
metadata = [
    ('project name', 'config/name="DIRTLINE MX Arcade 3.4.0"' in project),
    ('landscape', 'window/handheld/orientation=0' in project),
    ('GL compatibility', 'renderer/rendering_method="gl_compatibility"' in project),
    ('version name', 'version/name="3.4.0"' in export),
    ('version code', 'version/code=36' in export),
    ('package id', 'package/unique_name="com.carl.dirtlinemx.arcade30"' in export),
    ('workflow version', 'Arcade 3.4.0' in workflow),
    ('apk path', 'DIRTLINE-MX-Arcade-3.4.0.apk' in workflow and 'DIRTLINE-MX-Arcade-3.4.0.apk' in export),
]
for label,ok in metadata:
    if not ok: errors.append(f'METADATA CHECK FAILED: {label}')

# Regression / behavior source assertions.
checks={
    'scripts/Main.gd': ['func _activate_race_grid()','race_bike.activate_from_grid()','audio.bind_racers(racers)'],
    'scripts/Bike.gd': ['deterministic surface-follow movement','func _advance_airborne','func _surface_y','func _ground_pitch_at','func activate_from_grid()','func set_touch_throttle','func set_touch_lane_step'],
    'scripts/CameraRig.gd': ['camera_back_offset := 6.6','target.global_position.x - camera_back_offset'],
    'scripts/TrackBuilder.gd': ['add_to_group("race_track")','if side_view_mode:\n        _build_track_skirt(x_values)'],
    'scripts/HUD.gd': ['brand.name = "GameplayBrand"','ThrottleButton','BrakeButton','LaneUpButton','LaneDownButton','offset_right = 384.0','offset_left = -404.0'],
    'scripts/AudioManager.gd': ['AIEngineBed','func bind_racers','func _update_ai_engine_mix'],
    'scripts/SmokeTest.gd': ['DIRTLINE_SMOKETEST_V330_ARCADE_DRIVE_CLEARHUD_PARSESAFE','player_forward_delta','ai_forward_delta','camera_back_offset'],
}
for rel,needles in checks.items():
    t=(ROOT/rel).read_text('utf-8')
    for needle in needles:
        if needle not in t:
            errors.append(f'REGRESSION CHECK FAILED: {needle} missing from {rel}')

bike=(ROOT/'scripts/Bike.gd').read_text('utf-8')
for forbidden in ['move_and_slide()', 'is_on_floor()', 'get_floor_normal()']:
    if forbidden in bike:
        errors.append(f'OLD PHYSICS DEPENDENCY STILL PRESENT: {forbidden}')

hud=(ROOT/'scripts/HUD.gd').read_text('utf-8')
top=hud[hud.index('func _build_top_hud()'):hud.index('func _build_events()')]
if 'LOGO_MARK' in top or 'TextureRect.new()' in top:
    errors.append('GAMEPLAY HUD STILL CREATES A TEXTURE LOGO')

# No APK/key material in source package.
for p in ROOT.rglob('*'):
    if p.is_file() and p.suffix.lower() in {'.apk','.keystore','.jks'}:
        errors.append(f'UNEXPECTED BUILD/SECRET ARTIFACT: {p.relative_to(ROOT)}')

print('DIRTLINE MX 3.3.0 FULL AUDIT')
print(f'  resource references checked: {resource_refs}')
print(f'  GLB files checked: {glb_count}')
print(f'  images checked: {image_count}')
print(f'  WAV files checked: {wav_count}')
print(f'  OGG files checked: {ogg_count}')
print(f'  input actions used/defined: {len(used)}/{len(defined)}')
print(f'  errors: {len(errors)}')
print(f'  warnings: {len(warnings)}')
for e in errors: print('ERROR:',e)
for w in warnings: print('WARNING:',w)
if errors: sys.exit(1)
print('PASS: source integrity, clear-HUD, camera, and deterministic-drive regression checks completed successfully.')
