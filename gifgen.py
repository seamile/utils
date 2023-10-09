#!/usr/bin/env python

import sys
from os.path import exists
from argparse import ArgumentParser

from PIL import Image, UnidentifiedImageError

# 定义并解析参数
parser = ArgumentParser('gifgen')
parser.add_argument('-d', dest='duration', default=100, type=int,
                    help='每张图片的停留时间，单位：ms')
parser.add_argument('-s', dest='size', default='',
                    help='图片大小，格式为: "W,H" 或 "WxH"，默认为第一张图片的大小')
parser.add_argument('-f', dest='override', action='store_true',
                    help='是否覆盖已存在的文件')
parser.add_argument('-n', dest='n_play', type=int, help='播放次数, 默认为无限循环')
parser.add_argument('output', help='要创建的GIF文件名')
parser.add_argument('images', nargs='+', help='用来制作GIF的原图片，按顺序添加')
args = parser.parse_args()

kwargs = {'save_all': True}


# 读取图片列表
try:
    images = [Image.open(name) for name in args.images]
except (FileNotFoundError, UnidentifiedImageError) as err:
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

kwargs['append_images'] = images[1:]

# 设置循环次数 (循环次数为 1 时表示不循环，无需设置)
if args.n_play is None or args.n_play < 0:
    kwargs['loop'] = 0 # 无限循环
elif args.n_play > 1:
    kwargs['loop'] = args.n_play - 1

# 设置每一帧的播放时间
duration = 1 if args.duration < 1 else args.duration
kwargs['duration'] = duration

# 确认是否要覆盖
if exists(args.output) and not args.override:
    choice = input(f'"{args.output}" already exists, overwrite? [y/n] ')
    confirm = choice.lower() == 'y'
else:
    confirm = True

if confirm:
    # 保存GIF
    images[0].save(args.output, **kwargs)
else:
    print('canceled')
