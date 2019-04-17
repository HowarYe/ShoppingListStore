##############################################################################
# 
# Author     : H. Ye
# Email      : x
# 
# Description: user.ex file contains a module User which is a struct that 
# represents a user. Each User contains a username and a password.
##############################################################################
defmodule User do
	@enforce_keys [:username, :password]
	defstruct [:username, :password]
end
