################################################################################
# 
# Author     : H. Ye
# Email      : hye42@uwo.ca
# 
# Description: The ShoppingListServer module implements a shopping list server,
# handling requests from clients and making use of the ShoppingListStore and 
# UserStore to read and write data.
################################################################################

defmodule ShoppingListServer do

    def start() do
    
        # Spawn a linked UserStore process
        users_pid = spawn_link(UserStore, :start, [])
        
        # Spawn a linked ShoppingListStore process
        lists_pid = spawn_link(ShoppingListStore, :start, [])  

        # Leave this here
        Process.register(self(), :server)  

        # server_pid
        ser = self()

        # Start the message processing loop 
        loop(users_pid, lists_pid, ser)
    end

    def loop(users, lists, ser) do

        # Receive loop goes here
        #
        # For each request that is received, you MUST spawn a new process
        # to handle it (either here, or in a helper method) so that the main
        # process can immediately return to processing incoming messages
        #               
        receive do
            # create new user
            {caller, :new_user, username, password} ->
                # spawn a new process for new_user() to handle the reuqest;
                # must be spawn(fn -> func end)
                spawn(fn -> new_user(caller, users, username, password, ser) end)            
                loop(users, lists, ser)
            # get a sorted list of usernames
            {caller, :list_users} ->
                spawn(fn -> list_users(caller, users, ser) end)
                loop(users, lists, ser)
            # fetch the user's shopping list if authentication succeeds
            {caller, :shopping_list, username, password} ->
                spawn(fn -> shopping_list(caller, ser, users, lists, username, password) end)
                loop(users, lists, ser)
            # process to add the item to the user's shopping list if authentication succeeds
            {caller, :add_item, username, password, item} ->
                spawn(fn -> add_item(caller, ser, users, lists, username, password, item) end)
                loop(users, lists, ser)
            # process to delete the item from the user's shopping list if auth succeeds
            {caller, :delete_item, username, password, item} ->
                spawn(fn -> delete_item(caller, ser, users, lists, username, password, item) end)
                loop(users, lists, ser)
            # to clear all data in the system
            {caller, :clear} ->
                spawn(fn -> clear_a(caller, ser, users, lists) end)
                loop(users, lists, ser)
            # Exits the server
            {_caller, :exit} ->
                IO.puts "ShoppingListServer shutting down"
            # handle unmatched msg
            _ ->
                loop(users, lists, ser)

        end

    end

    # implement new_user to create new user by calling user_store process
    defp new_user(caller, users, username, password, ser) do
        send(users, {self(), :add, username, password})
        receive do
            {_, :added, _} ->
                send(caller, {ser, :ok, "User created successfully"})
            {_, :error, reason} ->
                send(caller, {ser, :error, reason})
            _ ->
                send(caller, {ser, :error, "An unknown error occurred"})
        end
    end

    # Sends a message to the UserStore process to get a sorted list of usernames
    defp list_users(caller, users, ser) do
        send(users, {self(), :list})
        receive do
            {_, :user_list, uList} ->
                send(caller, {ser, :ok, uList})
            _ ->
                send(caller, {ser, :error, "An unknown error occurred"})
        end
    end

    # 1. send msg to userStore process to authenticate 
    # 2. Sends a message to the ShoppingListStore process to fetch the user's shopping list
    defp shopping_list(caller, ser, users, lists, username, password) do
        send(users, {self(), :authenticate, username, password})
        receive do
            {_, :auth_failed, _} ->
                send(caller, {ser, :error, "Authentication failed"})
            {_, :auth_success, _} ->
                send(lists, {self(), :list, username})
                    receive do
                        {_, :list, _, items} ->
                            send(caller, {ser, :ok, items})
                        _ ->
                            send(caller, {ser, :error, "An unknown error occurred"})
                    end
        end
    end

    # 1. Sends a message to the UserStore process to authenticate the user
    # 2. if 1 succeeds, sends a message to the ShoppingListStore process to add the
    # item to the user's shopping list
    defp add_item(caller, ser, users, lists, username, password, item) do
        send(users, {self(), :authenticate, username, password})
        receive do
            {_, :auth_failed, _} ->
                send(caller, {ser, :error, "Authentication failed"})
            {_, :auth_success, _} ->
                send(lists, {self(), :add, username, item})
                    receive do
                        {_, :exists, _, _} ->
                            send(caller, {ser, :error, "Item '#{item}' already exists"})
                        {_, :added, _, _} ->
                            send(caller, {ser, :ok, "Item '#{item}' added to shopping list"})
                        _ ->
                            send(caller, {ser, :error, "An unknown error occurred"})
                    end
        end
    end

    # 1. Sends a message to the UserStore process to authenticate the user
    # 2. Sends a message to the ShoppingListStore process to delete the item from the
    # user's shopping list, if 1 succeeds.
    defp delete_item(caller, ser, users, lists, username, password, item) do
        send(users, {self(), :authenticate, username, password})
        receive do
            {_, :auth_failed, _} ->
                send(caller, {ser, :error, "Authentication failed"})
            {_, :auth_success, _} ->
                send(lists, {self(), :delete, username, item})
                    receive do
                        {_, :not_found, _, _} ->
                            send(caller, {ser, :error, "Item '#{item}' not found"})
                        {_, :deleted, _, _} ->
                            send(caller, {ser, :ok, "Item '#{item}' deleted from shopping list"})
                        _ ->
                            send(caller, {ser, :error, "An unknown error occurred"})
                    end
        end
    end

    # Sends appropriate messages to the UserStore and ShoppingListStore processes to 
    # clear all data in the system
    defp clear_a(caller, ser, users, lists) do
        send(users, {self(), :clear})
        receive do            
            {_, :cleared} ->
                send(lists, {self(), :clear})
                receive do
                    {_, :cleared} ->
                        send(caller, {ser, :ok, "All data cleared"})
                    _ ->
                        send(caller, {ser, :error, "An unknown error occurred"})
                end
            _ ->
                send(caller, {ser, :error, "An unknown error occurred"})
        end
    end

end
