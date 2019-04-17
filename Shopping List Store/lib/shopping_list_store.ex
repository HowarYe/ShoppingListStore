##############################################################################
#
# Author     : H. Ye
# Email      : hye42@uwo.ca
# 
# Description: The ShoppingListStore module manages shopping lists for users. 
# Shopping list files are stored as text files in db/lists/*, and one file is 
# stored per user. ShoppingListStore waits for messages, updating lists and/or
# returning information from lists to the caller, as appropriate.
##############################################################################
defmodule ShoppingListStore do

  # Path to the shopping list files (db/lists/*)
  # Don't forget to create this directory if it doesn't exist
  @database_directory Path.join("db", "lists")

  # Note: you will spawn a process to run this store in
  # ShoppingListServer.  You do not need to spawn another process here
  def start() do
    
    # Call your receive loop
    loop()
    
  end

  defp loop() do

    unless File.dir?(@database_directory) do
        File.mkdir_p(@database_directory)
    end
    receive do
      # Removes all shopping list files from db/lists
      {caller, :clear} ->
        clear(caller)
        loop()
      # Loads the user's shopping list from db/lists/USERNAME.txt
      {caller, :list, username} ->
        list(caller, username)
        loop()
      # Adds items into user's shopping list
      {caller, :add, username, item} ->
        add(caller, username, item)
        loop()
      # Delets items from list
      {caller, :delete, username, item} ->
        delete(caller, username, item)
        loop()
      # Exits list store
      {_caller, :exit} ->
        IO.puts "ShoppingListStore shutting down"
      # Always handle unmatched messages
      # Otherwise, they queue indefinitely
      _ ->
        loop()
    end

  end

  # Implement clear func
  defp clear(caller) do
    File.rm_rf @database_directory
    send(caller, {self(), :cleared})
  end

  # Implement returning user's shopping list
  defp list(caller, username) do
    unless File.exists?(user_db(username)) do
      File.write(user_db(username),"")
    end
    case File.read(user_db(username)) do
      {:ok, contents} -> 
        cont = String.split(contents, "\n")
        c2 = cont -- [""]
          |> Enum.sort
        send(caller,{self(), :list, username, c2})
      {:error, _} -> IO.puts "Can't read file #{username}.txt (shopping_list_store)"
    end
  end

  # Implement adding item into user's shopping list
  defp add(caller, username, item) do
    unless File.exists?(user_db(username)) do
      File.write(user_db(username),"")
    end
    case File.read(user_db(username)) do
      {:ok, contents} -> 
        cont = String.split(contents, "\n")
        if  contents =~ "#{item}\n" do
          # IO.puts "Error: Item '#{item}' already exists (shopping_list_store)"
          send(caller, {self(), :exists, username, item})
        else 
          userString = ["#{item}" | cont]
            |> Enum.join("\n")
          File.write(user_db(username), userString)
          send(caller, {self(), :added, username, item})
        end  
      
      {:error, _} -> IO.puts "Can't read file #{username}.txt (shopping_list_store)"
    end
  end

  # Implement deleting item
  defp delete(caller, username, item) do
    unless File.exists?(user_db(username)) do
      File.write(user_db(username),"")
    end
    #{_, contents} = File.read(user_db(username))
    case File.read(user_db(username)) do
      {:ok, contents} -> 
        if contents =~ "#{item}\n" do
          newString = String.replace(contents, "#{item}\n", "")
          File.write(user_db(username), newString)
          send(caller, {self(), :deleted, username, item})
        else
          send(caller, {self(), :not_found, username, item})
        end
      {:error, _} -> IO.puts "Can't read file #{username}.txt (shopping_list_store)"
    end
    
  end


  # Path to the shopping list file for the specified user
  # (db/lists/USERNAME.txt)
  defp user_db(username), do: Path.join(@database_directory, "#{username}.txt")

  # used =~ instead
  # check if item exist in the list, if exist return true else false
  #defp existOrNot(cont, item) do
  #  if Enum.at(cont, 0) == nil do
  #    false
  #  else 
  #    if Enum.at(cont, 0) == item, do: true, else: existOrNot(tl(cont), item)
  #  end
  #end

  # used Enum.join instead
  # building userlist
  #defp buildList([], item) do
  #  "#{item}"
  #end
  #defp buildList(cont, item) do
  #  Enum.at(cont, 0) <> " " <> buildList(tl(cont), item)
  #end

end
