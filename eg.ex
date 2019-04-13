defmodule Example do
	#def func(name, type \\ "student")
	
	#def func(name, "employee") do
	#	IO.puts("Hello employee #{name}")
	#end
	def func(name, type) do
		IO.puts("Hello #{type} #{name}")
	end
end

