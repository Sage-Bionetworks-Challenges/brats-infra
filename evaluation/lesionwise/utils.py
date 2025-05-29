"""Common util functions for validation and scoring."""
import os
import tarfile
import zipfile


def _is_hidden(member):
    """Check whether file is hidden or not."""
    hidden = ("__", "._", "~", ".DS_Store")
    return os.path.split(member)[1].startswith(hidden) or ".idea" in member


def _filter_tar(members, pattern):
    """Filter out directory name and hidden files in tarball."""
    files_to_extract = []
    for member in members:
        if member.isfile() and not _is_hidden(member.name) and \
                pattern in member.name:
            member.name = os.path.basename(member.name)
            files_to_extract.append(member)
    return files_to_extract


def _filter_zip(members, pattern):
    """Filter out directory name and hidden files in zip file."""
    files_to_extract = []
    for member in members:
        if not member.is_dir() and not _is_hidden(member.filename) and \
                pattern in member.filename:
            member.filename = os.path.basename(member.filename)
            files_to_extract.append(member)
    return files_to_extract


def inspect_zip(f, unzip=True, path=".", pattern=""):
    """Untar or unzip file."""
    if zipfile.is_zipfile(f):
        with zipfile.ZipFile(f) as zip_ref:
            members = _filter_zip(zip_ref.infolist(), pattern)
            if unzip:
                zip_ref.extractall(path=path, members=members)
            imgs = [member.filename for member in members]
    elif tarfile.is_tarfile(f):
        with tarfile.open(f) as tar_ref:
            members = _filter_tar(tar_ref, pattern)
            if unzip:
                tar_ref.extractall(path=path, members=members)
            imgs = [member.name for member in members]
    else:
        imgs = []
    return imgs
