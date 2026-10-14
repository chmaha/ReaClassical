Portable 7-Zip (`7z.exe` + `7z.dll`) used by the Windows installer (`web_src/win`) to unpack
REAPER's archive. `7zip.zip` is the 64-bit build and `7zip32.zip` the 32-bit one.

7-Zip is copyright Igor Pavlov, <https://www.7-zip.org>, distributed under the GNU LGPL
(with the unRAR licence restriction on the RAR code). These are unmodified builds, copied
from the former https://github.com/chmaha/7-zip repository so the installer does not
depend on a third-party repository. It is downloaded by the Windows install script from
`https://raw.githubusercontent.com/chmaha/ReaClassical/main/Installers/7zip/`.

SHA-256 (as copied on 2026-10-09):

    ce3c3821f107e1b2bbc1b870c0b188b74036c659f7356765379df07b4cae06e2  7zip.zip
    0be035b561ace2fbba2695322c25cb51d251c082eaad9d68685745166c62289a  7zip32.zip
