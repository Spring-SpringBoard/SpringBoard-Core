#!/usr/bin/python

from PIL import Image
import os

files = os.listdir(".")
for fname in files:
  if fname.endswith(".png"):
    img = Image.open(fname)
    #newImg = Image.new("RGBA", (img.width, img.size))
    #newImg = img.getdata()
    img = img.convert(mode="RGBA")
    img.save("../" + fname, "PNG")
