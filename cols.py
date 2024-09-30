#!/usr/bin/env python3
'''
从标准输入中提取指定列，并输出到标准输出
'''

import sys
from typing import Callable, Optional


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


def main():
    if len(sys.argv) < 2 or '-h' in sys.argv or '--help' in sys.argv:
        print(f'Usage: {sys.argv[0]} <col1>[,<col2> ...] [<files> ...]')
        sys.exit(0)
    else:
        try:
            columns = {int(col) - 1 for col in sys.argv[1].split(',')}
            if not all(col >= 0 for col in columns):
                raise ValueError
            else:
                columns = sorted(columns)
        except ValueError:
            print(f'Invalid column number: {sys.argv[1]}', file=sys.stderr)
            sys.exit(1)

        try:
            if len(sys.argv) == 2:
                files = [sys.stdin]
            else:
                files = [open(fname, 'r') for fname in sys.argv[2:]]
        except FileNotFoundError as e:
            print(e, file=sys.stderr)
            sys.exit(1)

        col_datas: list[list[str]] = [[] for _ in range(len(columns))]
        col_lens = [0 for _ in range(len(columns))]
        for file in files:
            for line in file:
                fields = DefaultList(line.split(), default_factory=str)
                for i, col in enumerate(columns):
                    field = fields[col]
                    col_datas[i].append(field)
                    col_lens[i] = max(col_lens[i], len(field))

        for fields in zip(*col_datas):
            line = ' '.join([field.ljust(col_lens[col]) for col, field in enumerate(fields)])
            print(line)

        for file in files:
            file.close()


if __name__ == '__main__':
    main()
