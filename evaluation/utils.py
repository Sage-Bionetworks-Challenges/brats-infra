"""Shared utility functions for BraTS evaluation scripts."""

import os
import tarfile
import zipfile


def _is_hidden(member: str) -> bool:
    """Check whether file is hidden or not."""
    hidden = ("__", "._", "~", ".DS_Store")
    return os.path.split(member)[1].startswith(hidden) or ".idea" in member


def _filter_archive_members(members, pattern, is_zip):
    """Filter out directories and hidden files from archive members."""
    files_to_extract = []
    for member in members:
        member_name = member.filename if is_zip else member.name
        is_file = not member.is_dir() if is_zip else member.isfile()
        if is_file and not _is_hidden(member_name) and pattern in member_name:
            if is_zip:
                member.filename = os.path.basename(member.filename)
            else:
                member.name = os.path.basename(member.name)
            files_to_extract.append(member)
    return files_to_extract


def inspect_archive(f, extract=True, path=".", pattern=""):
    """
    Inspect a tar/zipfile and optionally extract matching files to `path`.
    Returns a list of filenames found in the archive.
    """
    imgs = []
    if zipfile.is_zipfile(f):
        with zipfile.ZipFile(f) as zf:
            members = _filter_archive_members(
                zf.infolist(), pattern=pattern, is_zip=True
            )
            if extract:
                zf.extractall(path=path, members=members)
            imgs = [m.filename for m in members]
    elif tarfile.is_tarfile(f):
        with tarfile.open(f) as tf:
            members = _filter_archive_members(tf, pattern=pattern, is_zip=False)
            if extract:
                tf.extractall(path=path, members=members)
            imgs = [m.name for m in members]
    return imgs
