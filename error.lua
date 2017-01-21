local log = require('be.log')
local util = require('be.util')

function fatal (message, context, extra)
   log.fatal(message, extra)
   if context then
      log.verbose("Context", { context = util.sprint_r(context) })
   end
   error(message)
end

function warn (message, context, extra)
   log.warning(message, extra)
   if context then
      log.verbose("Context", { context = util.sprint_r(context) })
   end
end
