import os
import random
import csv
import time
import piexif
from PIL import Image
from geopy.geocoders import Nominatim

def dec_to_dms(deg):
    d = int(deg)
    md = abs(deg - d) * 60
    m = int(md)
    sd = (md - m) * 60
    return ((abs(d), 1), (m, 1), (int(sd * 10000), 10000))

def inject_exif(image_path, lat, lng):
    # Load image to determine format
    im = Image.open(image_path)
    
    # piexif works best with JPEGs. If it's PNG, we will just convert and save as JPEG 
    # but overwrite the same file (or rename it). To be safe, let's just convert it
    # in place and save as JPEG format even if extension is png, or rename it.
    # Renaming is cleaner.
    
    new_path = image_path
    if im.format == 'PNG':
        if im.mode in ("RGBA", "P"):
            im = im.convert("RGB")
        # Save as temp jpg
        temp_path = image_path + ".temp.jpg"
        im.save(temp_path, "JPEG", quality=95)
        os.remove(image_path)
        
        # Rename .png to .jpg for cleanliness
        if image_path.lower().endswith('.png'):
            new_path = image_path[:-4] + '.jpg'
        else:
            new_path = image_path + '.jpg'
        os.rename(temp_path, new_path)
        image_path = new_path

    try:
        exif_dict = piexif.load(image_path)
    except Exception:
        exif_dict = {"0th": {}, "Exif": {}, "GPS": {}, "Interop": {}, "1st": {}, "thumbnail": None}

    lat_ref = b'N' if lat >= 0 else b'S'
    lng_ref = b'E' if lng >= 0 else b'W'

    gps_ifd = {
        piexif.GPSIFD.GPSLatitudeRef: lat_ref,
        piexif.GPSIFD.GPSLatitude: dec_to_dms(lat),
        piexif.GPSIFD.GPSLongitudeRef: lng_ref,
        piexif.GPSIFD.GPSLongitude: dec_to_dms(lng),
    }

    exif_dict["GPS"] = gps_ifd
    exif_bytes = piexif.dump(exif_dict)
    
    piexif.insert(exif_bytes, image_path)
    return new_path

def main():
    images_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'images_pic')
    images_dir = os.path.abspath(images_dir)
    output_csv = os.path.join(os.path.dirname(__file__), 'images_metadata.csv')
    
    # Base location (New York for example)
    base_lat = 40.7128
    base_lng = -74.0060

    geolocator = Nominatim(user_agent="civic_ai_metadata_script")

    print(f"Scanning directory: {images_dir}")
    
    with open(output_csv, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['Filename', 'Latitude', 'Longitude', 'Address'])
        
        count = 0
        for root, _, files in os.walk(images_dir):
            for file in files:
                if file.lower().endswith(('.png', '.jpg', '.jpeg')):
                    file_path = os.path.join(root, file)
                    
                    # Random offset ~ 5km
                    lat = base_lat + random.uniform(-0.05, 0.05)
                    lng = base_lng + random.uniform(-0.05, 0.05)
                    
                    try:
                        address_str = "Unknown Address"
                        try:
                            location = geolocator.reverse(f"{lat}, {lng}", timeout=10)
                            if location:
                                address_str = location.address
                            # rate limit for Nominatim is 1 req / sec
                            time.sleep(1.1)
                        except Exception as e:
                            print(f"Geocoding failed for {lat}, {lng}: {e}")

                        new_path = inject_exif(file_path, lat, lng)
                        new_filename = os.path.basename(new_path)
                        writer.writerow([new_filename, lat, lng, address_str])
                        count += 1
                        print(f"Injected {new_filename} -> {lat:.5f}, {lng:.5f} | {address_str}")
                    except Exception as e:
                        print(f"Failed to inject {file}: {e}")
                        
        print(f"Total injected: {count}")
        print(f"Metadata saved to {output_csv}")

if __name__ == '__main__':
    main()
