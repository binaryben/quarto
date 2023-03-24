local function tableIncludes (needle, haystack)
  for _, item in ipairs(haystack) do
    if item == needle then
      return true
    end
  end

  return false
end