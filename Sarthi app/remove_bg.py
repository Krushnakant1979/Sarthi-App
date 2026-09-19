import os
from rembg import remove
from PIL import Image

input_path = "c:\\Users\\krush\\Sarthi\\Sarthi app\\assets\\images\\3d_parcel_delivery_new.jpg"
output_path = "c:\\Users\\krush\\Sarthi\\Sarthi app\\assets\\images\\3d_parcel_delivery_new.png"

input_image = Image.open(input_path)
output_image = remove(input_image)
output_image.save(output_path)
print("Background removed successfully!")
