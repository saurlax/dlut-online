"""Build directional shore-face modules above an unchanged geographic grid."""

import hashlib

from PIL import Image

from terrain_tiles import neighbor_mask, shape_mask

# Original pixel colors: grass lip, shallow soil face, submerged contact shadow.
# Eight display pixels express a low grass bank; this is not surveyed height.
PROFILE = [(183, 195, 111), (137, 165, 78), (112, 139, 66),
           (172, 151, 98), (153, 132, 85), (134, 116, 75),
           (105, 102, 69), (54, 103, 107)]


def assemble_shores(materials, bounds, directory):
    left, top, right, bottom = bounds
    width, height = right-left, bottom-top
    # The extra pixel border lets a face cross a cell seam or the preview crop.
    water = Image.new("1", ((width+2)*16, (height+2)*16))
    for y in range(top-1, bottom+1):
        for x in range(left-1, right+1):
            if materials[x,y] == "water":
                mask = neighbor_mask(lambda xx,yy: materials[xx,yy], x,y,"water")
                water.paste(shape_mask(mask), ((x-left+1)*16, (y-top+1)*16))

    tiles, cells = {}, []
    for y in range(height):
        for x in range(width):
            face = Image.new("RGBA", (16,16))
            for py in range(16):
                for px in range(16):
                    wx,wy=(x+1)*16+px,(y+1)*16+py
                    if not water.getpixel((wx,wy)):
                        continue
                    # Visible faces point south. A south bank hides its face;
                    # east/west banks reveal only the fronts of their turns.
                    for depth in range(len(PROFILE)):
                        if not water.getpixel((wx,wy-depth-1)):
                            color=PROFILE[depth]
                            world_x=(left+x)*16+px
                            if 3 <= depth <= 5 and world_x % 11 in (1,2):
                                color=PROFILE[min(depth+1,6)]
                            if 2 <= depth <= 3 and world_x % 9 in (1,2):
                                color=PROFILE[2]
                            if depth == 4 and world_x % 8 in (4,5,6):
                                color=(182,158,104)
                            if depth == 6 and world_x % 8 in (0,1):
                                color=(81,91,66)
                            if depth == 1 and world_x % 7 in (0,1):
                                color=PROFILE[2]
                            face.putpixel((px,py), (*color,255))
                            break
            if face.getbbox():
                name="shore-face-"+hashlib.sha256(face.tobytes()).hexdigest()[:12]
                if name not in tiles:
                    tiles[name]=face
                    face.save(directory/f"{name}.png",optimize=True)
                cells.append(name)
            else:
                cells.append(None)
    return tiles,cells
