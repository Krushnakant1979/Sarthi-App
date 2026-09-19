from PIL import Image

def remove_white_bg(image_path, output_path, threshold=235):
    img = Image.open(image_path).convert("RGBA")
    datas = img.getdata()

    newData = []
    for item in datas:
        # If the pixel is near-white
        if item[0] > threshold and item[1] > threshold and item[2] > threshold:
            newData.append((255, 255, 255, 0)) # Transparent
        else:
            newData.append(item)

    img.putdata(newData)
    img.save(output_path, "PNG")

remove_white_bg("c:\\Users\\krush\\Sarthi\\Sarthi app\\assets\\images\\3d_parcel_delivery_new.jpg", "c:\\Users\\krush\\Sarthi\\Sarthi app\\assets\\images\\3d_parcel_delivery_new.png")
print("Background made transparent!")
