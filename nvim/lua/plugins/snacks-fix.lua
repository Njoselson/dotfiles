-- Patch snacks.nvim git_status() to handle unknown status codes.
-- The explorer parser doesn't skip the second path of renamed files,
-- so paths like "1. 🚀 Projects/..." get misread as status code "1."
-- and crash. This wraps git_status to return "M" instead of erroring.
-- Remove when fixed upstream in folke/snacks.nvim.
return {
  {
    "folke/snacks.nvim",
    config = function(_, opts)
      require("snacks").setup(opts)
      local ok, git = pcall(require, "snacks.picker.source.git")
      if not ok then
        return
      end
      local orig = git.git_status
      git.git_status = function(xy)
        local success, result = pcall(orig, xy)
        if success then
          return result
        end
        return { status = "M", staged = false, priority = 3 }
      end
    end,
  },
}
