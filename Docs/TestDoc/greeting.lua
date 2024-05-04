
-- Filename: greeting.lua

--- @brief Greeting function in greeting.lua
-- This function prints a greeting to the named individual.
-- @param name The name of the person being greeted.
-- @param greeting The message to deliver.
-- @return Success True if the greeting was sent. False otherwise.
function sayHello(name, greeting)
    print(greeting .." ".. name)
    return true
end
-- End of sayHello function
