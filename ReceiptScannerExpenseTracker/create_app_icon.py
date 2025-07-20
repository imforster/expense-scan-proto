#!/usr/bin/env python3
"""
Script to create app icons for the Receipt Scanner Expense Tracker app.
Creates a simple, professional icon with a receipt and scanner theme.
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_app_icon():
    """Create a professional app icon for the Receipt Scanner app."""
    
    # Create the main 1024x1024 icon
    size = 1024
    icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    
    # Background gradient (blue to teal)
    for y in range(size):
        # Create a gradient from blue to teal
        ratio = y / size
        r = int(52 * (1 - ratio) + 0 * ratio)      # 52 -> 0
        g = int(152 * (1 - ratio) + 150 * ratio)   # 152 -> 150
        b = int(219 * (1 - ratio) + 136 * ratio)   # 219 -> 136
        
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    
    # Add a subtle rounded rectangle background
    margin = 80
    corner_radius = 180
    bg_rect = [margin, margin, size - margin, size - margin]
    
    # Create a rounded rectangle mask
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(bg_rect, radius=corner_radius, fill=255)
    
    # Apply the mask to create rounded corners
    icon.putalpha(mask)
    
    # Draw receipt shape (white paper with slight shadow)
    receipt_width = 280
    receipt_height = 400
    receipt_x = (size - receipt_width) // 2
    receipt_y = (size - receipt_height) // 2 - 40
    
    # Shadow
    shadow_offset = 8
    draw.rounded_rectangle(
        [receipt_x + shadow_offset, receipt_y + shadow_offset, 
         receipt_x + receipt_width + shadow_offset, receipt_y + receipt_height + shadow_offset],
        radius=20, fill=(0, 0, 0, 60)
    )
    
    # Main receipt
    draw.rounded_rectangle(
        [receipt_x, receipt_y, receipt_x + receipt_width, receipt_y + receipt_height],
        radius=20, fill=(255, 255, 255, 255)
    )
    
    # Receipt lines (to simulate text)
    line_color = (100, 100, 100, 180)
    line_width = 4
    
    # Header line (thicker)
    draw.rounded_rectangle(
        [receipt_x + 30, receipt_y + 40, receipt_x + receipt_width - 30, receipt_y + 55],
        radius=2, fill=line_color
    )
    
    # Regular lines
    for i in range(6):
        y_pos = receipt_y + 90 + (i * 35)
        line_length = receipt_width - 60 - (i % 3) * 40  # Vary line lengths
        draw.rounded_rectangle(
            [receipt_x + 30, y_pos, receipt_x + 30 + line_length, y_pos + 8],
            radius=2, fill=line_color
        )
    
    # Total line (thicker, at bottom)
    draw.rounded_rectangle(
        [receipt_x + 30, receipt_y + receipt_height - 80, receipt_x + receipt_width - 30, receipt_y + receipt_height - 65],
        radius=2, fill=(52, 152, 219, 255)
    )
    
    # Scanner beam effect (diagonal lines)
    beam_color = (255, 215, 0, 120)  # Golden yellow with transparency
    beam_width = 6
    
    for i in range(3):
        y_start = receipt_y + 100 + (i * 80)
        draw.line(
            [(receipt_x - 20, y_start), (receipt_x + receipt_width + 20, y_start + 40)],
            fill=beam_color, width=beam_width
        )
    
    # Add a small camera/scanner icon in the corner
    camera_size = 80
    camera_x = receipt_x + receipt_width - camera_size - 20
    camera_y = receipt_y - 30
    
    # Camera body
    draw.rounded_rectangle(
        [camera_x, camera_y, camera_x + camera_size, camera_y + camera_size],
        radius=15, fill=(64, 64, 64, 255)
    )
    
    # Camera lens
    lens_size = 40
    lens_x = camera_x + (camera_size - lens_size) // 2
    lens_y = camera_y + (camera_size - lens_size) // 2
    
    draw.ellipse(
        [lens_x, lens_y, lens_x + lens_size, lens_y + lens_size],
        fill=(32, 32, 32, 255)
    )
    
    # Lens reflection
    reflection_size = 15
    reflection_x = lens_x + 8
    reflection_y = lens_y + 8
    
    draw.ellipse(
        [reflection_x, reflection_y, reflection_x + reflection_size, reflection_y + reflection_size],
        fill=(255, 255, 255, 180)
    )
    
    return icon

def save_icon_sizes(base_icon):
    """Save the icon in different sizes required by iOS."""
    
    # iOS icon sizes (in pixels)
    sizes = [
        (1024, "1024x1024"),  # App Store
        (180, "60x60@3x"),    # iPhone app icon
        (120, "60x60@2x"),    # iPhone app icon
        (167, "83.5x83.5@2x"), # iPad Pro app icon
        (152, "76x76@2x"),    # iPad app icon
        (76, "76x76"),        # iPad app icon
        (58, "29x29@2x"),     # Settings icon
        (87, "29x29@3x"),     # Settings icon
        (80, "40x40@2x"),     # Spotlight icon
        (120, "40x40@3x"),    # Spotlight icon
    ]
    
    # Create directory if it doesn't exist
    icon_dir = "ReceiptScannerExpenseTracker/Assets.xcassets/AppIcon.appiconset"
    
    for size, name in sizes:
        resized_icon = base_icon.resize((size, size), Image.Resampling.LANCZOS)
        filename = f"{icon_dir}/icon_{name}.png"
        resized_icon.save(filename, "PNG")
        print(f"Created: {filename}")

def update_contents_json():
    """Update the Contents.json file to reference the new icon files."""
    
    contents = {
        "images": [
            {
                "filename": "icon_1024x1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            },
            {
                "filename": "icon_60x60@2x.png",
                "idiom": "iphone",
                "scale": "2x",
                "size": "60x60"
            },
            {
                "filename": "icon_60x60@3x.png",
                "idiom": "iphone",
                "scale": "3x",
                "size": "60x60"
            },
            {
                "filename": "icon_76x76.png",
                "idiom": "ipad",
                "scale": "1x",
                "size": "76x76"
            },
            {
                "filename": "icon_76x76@2x.png",
                "idiom": "ipad",
                "scale": "2x",
                "size": "76x76"
            },
            {
                "filename": "icon_83.5x83.5@2x.png",
                "idiom": "ipad",
                "scale": "2x",
                "size": "83.5x83.5"
            },
            {
                "filename": "icon_29x29@2x.png",
                "idiom": "iphone",
                "scale": "2x",
                "size": "29x29"
            },
            {
                "filename": "icon_29x29@3x.png",
                "idiom": "iphone",
                "scale": "3x",
                "size": "29x29"
            },
            {
                "filename": "icon_40x40@2x.png",
                "idiom": "iphone",
                "scale": "2x",
                "size": "40x40"
            },
            {
                "filename": "icon_40x40@3x.png",
                "idiom": "iphone",
                "scale": "3x",
                "size": "40x40"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    import json
    
    contents_path = "ReceiptScannerExpenseTracker/Assets.xcassets/AppIcon.appiconset/Contents.json"
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)
    
    print(f"Updated: {contents_path}")

if __name__ == "__main__":
    print("Creating Receipt Scanner app icon...")
    
    try:
        # Create the base icon
        icon = create_app_icon()
        
        # Save in different sizes
        save_icon_sizes(icon)
        
        # Update Contents.json
        update_contents_json()
        
        print("\n✅ App icon created successfully!")
        print("The icon features:")
        print("- Professional blue gradient background")
        print("- White receipt with text lines")
        print("- Scanner beam effect")
        print("- Small camera icon")
        print("- All required iOS sizes generated")
        
    except ImportError:
        print("❌ Error: PIL (Pillow) is required to create icons.")
        print("Install it with: pip install Pillow")
    except Exception as e:
        print(f"❌ Error creating icon: {e}")