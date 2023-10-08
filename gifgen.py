#!/usr/bin/env python

import sys
from argparse import ArgumentParser

from PIL import Image

# 定义并解析参数
parser = ArgumentParser('gifgen')
parser.add_argument('-d', dest='duration', default=100, type=int,
                    help='每张图片的停留时间，单位：ms')
parser.add_argument('-s', dest='size', default='',
                    help='图片大小，格式为: "W,H" 或 "WxH"，默认为第一张图片的大小')
parser.add_argument('output', help='要创建的GIF文件名')
parser.add_argument('images', nargs='+', help='用来制作GIF的原图片，按顺序添加')
args = parser.parse_args()

# 读取图片列表
try:
    images = [Image.open(name) for name in args.images]
except FileNotFoundError as err:
    print(err)
    sys.exit(1)

# 获取要保存的GIF大小
if args.size.count(',') == 1:
    size = tuple(int(pix) for pix in args.size.split(','))
elif args.size.count('x') == 1:
    size = tuple(int(pix) for pix in args.size.split('x'))
else:
    size = images[0].size

# 调整image列表
for i, img in enumerate(images):
    if img.size != size:
        images[i] = img.resize(size)  # type: ignore


# 保存GIF
duration = 1 if args.duration < 1 else args.duration
images[0].save(args.output, save_all=True, loop=0,
               append_images=images[1:], duration=duration)
