"""Utility functions for validation and scoring."""

import os
import tarfile
import zipfile


def _is_hidden(member: str) -> bool:
    """Check whether file is hidden or not."""
    hidden = ("__", "._", "~", ".DS_Store")
    return os.path.split(member)[1].startswith(hidden) or ".idea" in member


def _filter_archive_members(
    members: zipfile.ZipInfo | tarfile.TarInfo,
    pattern: str,
    is_zip: bool,
) -> list[str]:
    """Filter out directory name and hidden files in tar/zipfile."""
    files_to_extract = []
    for member in members:
        member_name_attr = member.filename if is_zip else member.name
        is_file = not member.is_dir() if is_zip else member.isfile()

        if is_file and not _is_hidden(member_name_attr) and \
                pattern in member_name_attr:
            if is_zip:
                member.filename = os.path.basename(member.filename)
            else:
                member.name = os.path.basename(member.name)
            files_to_extract.append(member)
    return files_to_extract


def inspect_archive(
    f: str,
    extract: bool = True,
    dest_path: str = ".",
    pattern: str = "",
) -> list[str]:
    """
    Inspect a tar/zipfile and optionally extract files that match the
    criteria (default is to extract all). Returns a list of filenames
    found in the archive.
    """
    imgs = []
    if zipfile.is_zipfile(f):
        with zipfile.ZipFile(f) as zip_ref:
            members = _filter_archive_members(
                zip_ref.infolist(), pattern=pattern, is_zip=True
            )
            if extract:
                zip_ref.extractall(path=dest_path, members=members)
            imgs = [member.filename for member in members]
    elif tarfile.is_tarfile(f):
        with tarfile.open(f) as tar_ref:
            members = _filter_archive_members(tar_ref, pattern=pattern, is_zip=False)
            if extract:
                tar_ref.extractall(path=dest_path, members=members)
            imgs = [member.name for member in members]
    return imgs
