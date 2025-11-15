#!/usr/bin/env python

import os
import sys
from queue import Queue
from threading import Thread

from moviepy.editor import VideoFileClip


def get_video_duration(path):
    if path.endswith('.mp4') and os.path.isfile(path):
        return VideoFileClip(path).duration
    else:
        return 0.0


def handle(path, queue):
    dur = get_video_duration(path)
    queue.put(dur)


def print_duration(seconds):
    seconds = int(seconds)
    days, seconds = divmod(seconds, 86400)
    hours, seconds = divmod(seconds, 3600)
    minutes, seconds = divmod(seconds, 60)

    res = ''
    if days:
        res += f' {days} 天'
    if hours:
        res += f' {hours} 小时'
    if minutes:
        res += f' {minutes} 分'
    res += f' {seconds} 秒'
    print(res)

if __name__ == '__main__':
    total = 0
    queue: Queue[int] = Queue()

    for f in sys.argv[1:]:
        Thread(target=handle, args=(f, queue)).start()

    for _ in sys.argv[1:]:
        total += queue.get()

    print_duration(total)
