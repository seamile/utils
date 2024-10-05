#!/usr/bin/env python3
'''
从标准输入中提取指定列，并输出到标准输出
'''

import itertools
import shutil
import sys
from argparse import ArgumentParser
from pathlib import Path
from typing import Callable, Optional

parser = ArgumentParser()
group = parser.add_mutually_exclusive_group()
group.add_argument('-d', '--delete', action='store_true', help='删除输入文件')
group.add_argument('-l', '--link', type=Path, help='链接输入文件到指定目录')
group.add_argument('-m', '--move', type=Path, help='移动输入文件到指定目录')
parser.add_argument('--offset', type=int, default=0, help='从第几行开始提取')
parser.add_argument('columns', type=str, help='要提取的列号，以逗号分隔')
parser.add_argument('files', nargs='*', help='目标文件，默认为标准输入')


class DefaultList(list):
    '''与 defaultdict 类似的支持动态创建默认值的 list'''

    def __init__(self, iterable=(), default_factory: Optional[Callable] = None):
        super().__init__(iterable)
        self.default_factory = default_factory

    def _get_default(self):
        return None if self.default_factory is None else self.default_factory()

    def __getitem__(self, index):
        try:
            return super().__getitem__(index)
        except IndexError:
            length = len(self)
            if index >= 0:
                self.extend([self._get_default() for _ in range(index + 1 - length)])
            elif index < 0:
                for _ in range(-index - length):
                    self.insert(0, self._get_default())
            return super().__getitem__(index)


def read_fields(files: list[str], offset: int):
    '''读取文件，返回每行的字段列表'''
    if not files:
        for n_row, line in enumerate(sys.stdin):
            if n_row >= offset:
                yield DefaultList(line.split(), default_factory=str)
    else:
        n_row = 0
        for file in files:
            with open(file, 'r') as fp:
                for line in fp:
                    if n_row >= offset:
                        yield DefaultList(line.split(), default_factory=str)
                    n_row += 1


def parse_columns(columns: str):
    '''解析要提取的列的索引'''
    try:
        _columns = {int(col) - 1 for col in columns.split(',')}
        if not all(col >= 0 for col in _columns):
            raise ValueError
        else:
            return sorted(_columns)
    except ValueError:
        print(f'Invalid column: {columns}', file=sys.stderr)
        sys.exit(1)


def confirm(prompt: str) -> bool:
    '''从终端获取用户确认'''
    try:
        print(f'{prompt} (y/n): ', file=sys.stderr, end='', flush=True)
        with open('/dev/tty') as tty:
            response = tty.readline().strip().lower()
            return response == 'y' or response == 'yes'
    except IOError:
        print("can't open tty", file=sys.stderr)
        return False
    except KeyboardInterrupt:
        print("user cancel", file=sys.stderr)
        return False


def main():
    args = parser.parse_args()

    col_indexes = parse_columns(args.columns)  # 要提取的列的索引
    n_cols = len(col_indexes)
    rows = [[fields[col] for col in col_indexes] for fields in read_fields(args.files, args.offset)]
    if not rows:
        print('No data', file=sys.stderr)
        sys.exit(1)

    col_lens = [max([len(row[i]) for row in rows]) for i in range(n_cols)]

    for fields in rows:
        line = '    '.join([field.ljust(col_lens[col]) for col, field in enumerate(fields)])
        print(line)

    paths = (Path(item) for item in itertools.chain(*rows))

    if args.delete:
        if confirm('Are you sure to delete above files or directories ?'):
            for path in paths:
                if path.is_dir():
                    print(f'deleting dir : {path}')
                    shutil.rmtree(path)
                elif path.is_file():
                    print(f'deleting file: {path}')
                    path.unlink()
                else:
                    print(f'Invalid path: {path}', file=sys.stderr)

    elif args.link:
        if args.link.is_dir():
            if confirm(f'Are you sure to link these files into "{args.link}" ?'):
                for path in paths:
                    if path.is_file():
                        try:
                            target = args.link / path.name
                            print(f'linking file: {path} -> {target}')
                            target.hardlink_to(path)
                        except OSError as e:
                            print(e, file=sys.stderr)
                    else:
                        print(f'The "{path}" is not a file', file=sys.stderr)
        else:
            print(f'Invalid directory: {args.link}', file=sys.stderr)
            sys.exit(1)

    elif args.move:
        if args.move.is_dir():
            if confirm(f'Are you sure to move these files into "{args.move}" ?'):
                for path in paths:
                    if path.is_file() or path.is_dir():
                        try:
                            path.rename(args.move / path.name)
                        except OSError as e:
                            print(f'Move "{path}" failed: {e}', file=sys.stderr)
                    else:
                        print(f'The "{path}" is not file or directory', file=sys.stderr)
        else:
            print(f'Invalid directory: {args.move}', file=sys.stderr)
            sys.exit(1)


if __name__ == '__main__':
    main()
