"""Builds SupermarketEmpire.rbxlx from default.project.json. Standard library only.

A stand-in for `rojo build` so the place can be opened in Studio without installing
anything. Run from the project root:  python tools/build_place.py
Naming follows Rojo: *.server.luau = Script, *.client.luau = LocalScript,
other *.luau = ModuleScript, a folder = Folder.
"""
import json
import os
import uuid
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "SupermarketEmpire.rbxlx")


def referent():
    return "RBX" + uuid.uuid4().hex.upper()


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def script_item(path, name, class_name):
    with open(path, encoding="utf-8") as f:
        source = f.read()
    return (
        f'<Item class="{class_name}" referent="{referent()}"><Properties>'
        f'<string name="Name">{escape(name)}</string>'
        f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
        "</Properties></Item>"
    )


def file_item(path, name=None):
    base = os.path.basename(path)
    for suffix, class_name in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if base.endswith(suffix):
            return script_item(path, name or base[: -len(suffix)], class_name)
    raise ValueError(f"not a Luau file: {path}")


def folder_item(path, name):
    children = "".join(
        folder_item(os.path.join(path, entry), entry)
        if os.path.isdir(os.path.join(path, entry))
        else file_item(os.path.join(path, entry))
        for entry in sorted(os.listdir(path))
        if os.path.isdir(os.path.join(path, entry)) or entry.endswith(".luau")
    )
    return (
        f'<Item class="Folder" referent="{referent()}"><Properties>'
        f'<string name="Name">{escape(name)}</string></Properties>{children}</Item>'
    )


def tree_item(name, node):
    if "$path" in node:
        path = os.path.join(ROOT, node["$path"])
        return folder_item(path, name) if os.path.isdir(path) else file_item(path, name)
    children = "".join(tree_item(k, v) for k, v in node.items() if not k.startswith("$"))
    return (
        f'<Item class="{escape(node.get("$className", name))}" referent="{referent()}"><Properties>'
        f'<string name="Name">{escape(name)}</string></Properties>{children}</Item>'
    )


def main():
    with open(os.path.join(ROOT, "default.project.json"), encoding="utf-8") as f:
        project = json.load(f)
    services = "".join(tree_item(k, v) for k, v in project["tree"].items() if not k.startswith("$"))
    workspace = (
        f'<Item class="Workspace" referent="{referent()}"><Properties>'
        '<string name="Name">Workspace</string>'
        '<bool name="StreamingEnabled">true</bool>'
        "</Properties></Item>"
    )
    xml = (
        '<roblox version="4">'
        "<External>null</External><External>nil</External>"
        f"{workspace}{services}</roblox>"
    )
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)
    print(f"Wrote {OUT} ({os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
    main()
