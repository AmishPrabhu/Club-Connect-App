#!/usr/bin/env python3
import os
from PIL import Image

def generate_icons():
    source_path = 'assets/images/club_connect_logo.png'
    if not os.path.exists(source_path):
        print(f"Error: {source_path} not found")
        return

    logo = Image.open(source_path).convert('RGBA')

    # Create a 1024x1024 white background tile for the master icon
    master_size = 1024
    master_icon = Image.new('RGBA', (master_size, master_size), (255, 255, 255, 255))
    
    # Scale logo with slight padding (85% of total size)
    padding_factor = 0.85
    target_logo_size = int(master_size * padding_factor)
    
    # Resize logo maintaining ratio
    logo_resized = logo.resize((target_logo_size, target_logo_size), Image.Resampling.LANCZOS)
    
    # Paste centered onto white background tile
    offset = (master_size - target_logo_size) // 2
    master_icon.paste(logo_resized, (offset, offset), logo_resized)

    # Foreground for Android adaptive icon (transparent background)
    fg_icon = Image.new('RGBA', (master_size, master_size), (0, 0, 0, 0))
    fg_logo_size = int(master_size * 0.65) # Adaptive safe zone
    fg_resized = logo.resize((fg_logo_size, fg_logo_size), Image.Resampling.LANCZOS)
    fg_offset = (master_size - fg_logo_size) // 2
    fg_icon.paste(fg_resized, (fg_offset, fg_offset), fg_resized)

    # -------------------------------------------------------------
    # 1. iOS App Icons
    # -------------------------------------------------------------
    ios_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    os.makedirs(ios_dir, exist_ok=True)
    
    ios_sizes = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
    }

    for filename, sz in ios_sizes.items():
        out_img = master_icon.resize((sz, sz), Image.Resampling.LANCZOS)
        out_img.save(os.path.join(ios_dir, filename))
        print(f"Generated iOS: {filename} ({sz}x{sz})")

    # -------------------------------------------------------------
    # 2. Android App Icons
    # -------------------------------------------------------------
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    for folder, sz in android_sizes.items():
        folder_path = os.path.join('android/app/src/main/res', folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # Standard launcher icon (with white tile)
        out_img = master_icon.resize((sz, sz), Image.Resampling.LANCZOS)
        out_img.save(os.path.join(folder_path, 'ic_launcher.png'))
        out_img.save(os.path.join(folder_path, 'ic_launcher_round.png'))
        
        # Adaptive foreground
        fg_out = fg_icon.resize((sz, sz), Image.Resampling.LANCZOS)
        fg_out.save(os.path.join(folder_path, 'ic_launcher_foreground.png'))
        print(f"Generated Android {folder}: {sz}x{sz}")

    # -------------------------------------------------------------
    # 3. Web Icons & Favicon
    # -------------------------------------------------------------
    web_dir = 'web/icons'
    os.makedirs(web_dir, exist_ok=True)

    master_icon.resize((32, 32), Image.Resampling.LANCZOS).save('web/favicon.png')
    master_icon.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_dir, 'Icon-192.png'))
    master_icon.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_dir, 'Icon-512.png'))
    master_icon.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_dir, 'Icon-maskable-192.png'))
    master_icon.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_dir, 'Icon-maskable-512.png'))
    print("Generated Web Favicon and PWA icons")

    print("\nSUCCESS: All launcher icons generated successfully!")

if __name__ == '__main__':
    generate_icons()
