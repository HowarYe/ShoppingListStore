##############################################################################
# 
# Author     : H. Ye
# Email      : hye42@uwo.ca
# 
# Description: The UserStore module manages a database of users, storing their
# usernames and passwords. The user database is a simple text file stored in 
# db/users.txt, with one user stored per line. UserStore waits for messages, 
# keeping a copy of the user database in memory, updating the database file as
# needed, and handling incoming user creation and authentication requests.
##############################################################################

import User

defmodule UserStore do

  # Path to the user database file
  # Don't forget to create this directory if it doesn't exist
  @database_directory "db"

  # Name of the user database file
  @user_database "users.txt"

  # Note: you will spawn a process to run this store in
  # ShoppingListServer.  You do not need to spawn another process here
  def start() do
    # Load your users and start your loop
    loop(%{})

  end

  defp loop(map) do
    # create db dir if not exist
    unless File.dir?(@database_directory) do
        File.mkdir(@database_directory)
    end
    receive do
      # Remove all users from database
      {caller, :clear} ->
        clear(caller)
        loop(%{})
      # Retrieves a sorted list of all usernames in the database
      {caller, :list} ->
        list(caller)
        loop(map)
      # Adder a new user into db if does not exist
      {caller, :add, username, password} ->
        m = add(caller, username, password, map)
        loop(m)
      # Check if username and its pw match with db data
      {caller, :authenticate, username, password} ->
        authenticate(caller, username, password)
        loop(map)
      # Exit User store
      {_caller, :exit} ->
        IO.puts "UserStore shutting down"
      # handle unmatched messages
      _ ->
        loop(map)
    end
  end

  # Remove users from db & memory
  defp clear(caller) do
    File.rm_rf @database_directory
    send(caller, {self(), :cleared})
  end

  # Implement returning the users' list
  defp list(caller) do
    unless File.exists?(user_database()) do
      File.write(user_database(),"")
    end
    # send(caller, {self(), :user_list, Map.keys(map)}) // for list(caller, map)
    case File.read(user_database()) do
      {:ok, contents} -> 
        if contents == "" do
          send(caller,{self(), :user_list,[]})
        else
          # remove "" from the splitted list
          cont = String.split(contents, "\n") -- [""]
          leng = length(cont)          
          l = find_user(cont,0,leng)
            |> Enum.sort
          send(caller,{self(), :user_list, l})
        end
        
      {:error, _} -> IO.puts "Can't read file users.txt (list: User_store)"
    end   
  end

  # Implement Add user & its pw into db
  defp add(caller, username, password, map) do
    unless File.exists?(user_database()) do
      File.write(user_database(),"")
    end
    case File.read(user_database()) do
      {:ok, contents} ->         
        if  contents =~ "#{username}" do
          send(caller, {self(), :error, "User already exists"})
        else 
          h = hash_password(password)
          user = %User{username: "#{username}", password: "#{h}"}
          userString = contents <> "#{username}:#{h}\n"
          File.write(user_database(), userString)
          send(caller, {self(), :added, user})
          Map.put(map, "#{username}", "#{h}")        
        end  
      
      {:error, _} -> 
        IO.puts "Can't read file users.txt (add: User_store)"
        map
    end
  end

  # Implement Authenticate
  defp authenticate(caller, username, password) do
    unless File.exists?(user_database()) do
      File.write(user_database(),"")
    end
    case File.read(user_database()) do
      {:ok, contents} ->         
        unless contents =~ "#{username}" do
          send(caller, {self(), :auth_failed, username})
        else
          h = hash_password(password)
          unless contents =~ "#{h}" do
            send(caller, {self(), :auth_failed, username})
          else
            send(caller, {self(), :auth_success, username})
          end
        end
                
      {:error, _} -> IO.puts "Can't read file users.txt (auth: User_store)"
    end 
    # wont work for persists to disk so what's the use of memory?
    #unless Map.has_key?(map, "#{username}") do
    #  send(caller, {self(), :auth_failed, username})
    #else
    #  h = hash_password(password)
    #  if Map.get(map, "#{username}") != h do
    #    send(caller, {self(), :auth_failed, username})
    #  else
    #    send(caller, {self(), :auth_success, username})
    #  end
    #end
  end

  # Path to the user database
  defp user_database(), do: Path.join(@database_directory, @user_database)

  # Use this function to hash your passwords
  defp hash_password(password) do
    hash = :crypto.hash(:sha256, password)
    Base.encode16(hash)
  end

  # find all the usernames from the file
  defp find_user(list, count, leng) do
    u = Enum.at(list,count)
    {x,_} = :binary.match(u, ":")
    user = String.slice(u, 0..x-1)
    check = count + 1
    if check < leng do
      [user] ++ find_user(list, check, leng) 
    else 
      [user]
    end
  end

end
