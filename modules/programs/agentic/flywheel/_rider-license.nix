# Shared rider-carrying license for the flywheel tool packages: the MIT
# grant excludes OpenAI/Anthropic (and their agents), so this is never
# lib.licenses.mit. Underscore prefix keeps this out of import-tree;
# imported directly by each package file, which layers on its own url.
{
  fullName = "MIT License (with OpenAI/Anthropic Rider)";
  shortName = "mit-openai-anthropic-rider";
  free = false;
  redistributable = false;
}
