from pkgutil import iter_modules
from sys import argv
from os.path import join


def get_modules(path: str, depth: int, is_root: bool = True) -> list[str]:
    names = [name for _, name, _ in iter_modules([path])]

    child_names = []
    if depth > 0:
        for parent in names:
            child_names.extend(
                [
                    f"{parent}.{child}"
                    for child in get_modules(join(path, parent), depth - 1, False)
                ]
            )

    if is_root:
        return child_names
    else:
        names.extend(child_names)
        return names


if __name__ == "__main__":
    if len(argv) > 1:
        path = argv[1]
    else:
        path = "."

    if len(argv) > 2:
        depth = int(argv[2])
    else:
        depth = 1

    for name in get_modules(path, depth):
        print(name)
