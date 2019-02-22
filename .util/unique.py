#!/usr/bin/python3
# vim: fileencoding=utf-8

import os

class DoNotStarve:

    def __init__(self, path_home):
        self.home = path_home.replace('/', os.sep)
        assert os.path.isdir(self.home)
        self.paths = [os.path.join(self.home, path.replace('/', os.sep)) for path in [
            "data/scripts",
            "data/DLC0001/scripts",
            "data/DLC0002/scripts",
            "data/DLC0003/scripts",
        ]]

    def GetPaths(self, module):
        return [os.path.join(path, module) for path in self.paths]

    def GetUniqueFiles(self, module):
        paths = self.GetPaths(module.replace('/', os.sep))
        unique = {}
        modules = {}

        for path in paths:
            files = [f for f in os.listdir(path) if os.path.isfile(os.path.join(path, f))]
            key = path[len(self.home):]
            modules[key] = []
            for file in files:
                if unique.get(file):
                    continue
                unique[file] = True
                modules[key].append(file)

        return modules

if __name__ == '__main__':
    path_home = input("Please input absolute path of working directory of Don't Starve:")
    if not path_home.endswith("steamapps/common/dont_starve".replace('/', os.sep)):
        print("Invalid input string!")
        exit(-1)

    inst = DoNotStarve(path_home)
    modules = inst.GetUniqueFiles("map/rooms")
    index = 0
    for path, files in modules.items():
        if index > 0:
            print('------------------------')
        else:
            print("========================")
        index += 1

        print("Path:", path)
        print("Files:")
        for file in files:
            print('', file)
    print("========================")
