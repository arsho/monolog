# ******************************************************************************
# Copyright 2025 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the Monolog project.
# For more info, see https://github.com/arsho/monolog
#
# SPDX-License-Identifier: BSD-3-Clause
# ******************************************************************************
"""Sphinx configuration for the Monolog documentation.

Build locally:

    python3 -m pip install -r docs/requirements.txt
    sphinx-build -b html docs docs/_build/html
"""

import datetime

# -- Project information -----------------------------------------------------

project = "Monolog"
author = "Ahmedur Rahman Shovon, Romain Pereira, Swann Perarnau"
copyright = f"{datetime.date.today().year}, UChicago Argonne, LLC"
release = "1.0.0"
version = release

# -- General configuration ---------------------------------------------------

extensions = [
    "myst_parser",
    "sphinx.ext.intersphinx",
    "sphinx_copybutton",
]

myst_enable_extensions = [
    "colon_fence",
    "deflist",
    "linkify",
    "substitution",
    "tasklist",
]

# Auto-generate anchors for headings up to <h4> so cross-file links such as
# `baselines.md#validating-a-gpulog-run-result-size-cross-check` resolve.
myst_heading_anchors = 4

source_suffix = {
    ".md": "markdown",
    ".rst": "restructuredtext",
}

master_doc = "index"

exclude_patterns = [
    "_build",
    "Thumbs.db",
    ".DS_Store",
    "requirements.txt",
]

# -- HTML output -------------------------------------------------------------

html_theme = "sphinx_rtd_theme"
html_title = "Monolog"
html_short_title = "Monolog"

html_theme_options = {
    "collapse_navigation": False,
    "navigation_depth": 3,
    "sticky_navigation": True,
    "titles_only": False,
    "style_external_links": True,
}

html_context = {
    "display_github": True,
    "github_user": "arsho",
    "github_repo": "monolog",
    "github_version": "main",
    "conf_py_path": "/docs/",
}

# -- Copy-button -------------------------------------------------------------

# Strip shell prompts so a copied block pastes cleanly.
copybutton_prompt_text = r"\$ |> |\.\.\. "
copybutton_prompt_is_regexp = True

# -- Intersphinx -------------------------------------------------------------

intersphinx_mapping = {
    "python": ("https://docs.python.org/3", None),
}
