# Pilot Hubs deployment infrastructure

This repository contains deployment infrastucture and documentation for a federation of JupyterHubs that 2i2c manages for various communities.

See [the Pilot Hubs documentation](https://pilot-hubs.2i2c.org) for more information.

## Building the documentation

To build this documentation follow these steps:

1. Create a `conda` environment to build the documentation.
   
   ```bash
   conda env create -f docs/environment.yml -n pilot-hubs-docs
   ```

2. Activate the new environment:

   ```bash
   conda activate pilot-hubs-docs
   ```

3. Build the documentation:
   
   ```
   make html
   ```

This will generate the HTML for the documentation in the `docs/_build/html` folder.
You may preview the documentation by opening any of the `.html` files inside.

**Build the documentation with a live server**. You can optionally build the documentation with a **live server** to automatically preview the changes as you build the docs. To use this, run `make live` instead of `make html`.
