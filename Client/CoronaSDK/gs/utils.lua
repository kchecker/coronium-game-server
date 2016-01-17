--======================================================================--
--== Utils
--======================================================================--

--- Client Utilities
-- @module Utils
local Utils = {}

--======================================================================--
--== Code
--======================================================================--

--- Pretty print table data.
-- @tparam table t The table data to print.
-- @param[opt=""] indent Indentation char.
function Utils:printTable( t, indent )
  --== Print contents of a table, with keys sorted.
  local names = {}
  if not indent then indent = "" end
  for n,g in pairs(t) do
      table.insert(names,n)
  end
  table.sort(names)
  for i,n in pairs(names) do
      local v = t[n]
      if type(v) == "table" then
          if(v==t) then -- prevent endless loop if table contains reference to itself
              print(indent..tostring(n)..": <-")
          else
              print(indent..tostring(n)..":")
              self:printTable(v,indent.."   ")
          end
      else
          if type(v) == "function" then
              print(indent..tostring(n).."()")
          else
              print(indent..tostring(n)..": "..tostring(v))
          end
      end
  end
end

--- An alias to the printTable method.
-- @tparam table tbl The table data to print.
-- @usage utils.p( table_to_print )
Utils.p = function( tbl )
  if tbl then
    if type( tbl ) == "table" then
      Utils:printTable( tbl )
    else
      print( tostring( tbl ) )
    end
  end
end

--======================================================================--
--== Return
--======================================================================--

return Utils
