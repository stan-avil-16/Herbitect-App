# Herbal_i

Project files tracked with Git and Git LFS.

## Getting Started
- Clone: git clone https://github.com/stan-avil-16/herbal_i.git
- Install Git LFS once: git lfs install
- Pull LFS files: git lfs pull

## Development
- Keep large/binary assets in LFS (images, media, models, zips).
- Do not commit data dumps or build outputs; they are ignored by .gitignore.

## Large Files
If you see a file >100 MB, ensure it's matched by .gitattributes (LFS). To add new patterns:

`ash
git lfs track "path/or/pattern/*"
`

Commit the updated .gitattributes.