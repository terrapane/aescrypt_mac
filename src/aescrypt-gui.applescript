--
-- AES Crypt Launcher for Mac
-- Copyright (C) 2025
-- Terrapane Corporation
-- Author: Paul E. Jones <paulej@packetizer.com>
--

global stop_requested

-- Initialize globals used by this script
on InitializeGlobals()
	global stop_requested

	set stop_requested to false
end InitializeGlobals

-- Handler to run when the user opens AES Crypt
on run
	local file_list

	-- Initialize the global variables
	InitializeGlobals()

	-- Ensure the application is brought to the front
	activate

	try
		set file_list to choose file ¬
			with prompt "AES Crypt (Select file(s) to encrypt or decrypt)" ¬
			with multiple selections allowed
	on error e number error_number
		if error_number is -128 then
			-- User pressed "Cancel"
			set file_list to {}
		else
			-- All other errors will render a message
			MessageDialog("An error occurred: " & (e as text))
			set file_list to {}
		end if
	end try

	-- If the user selected one or more files, process the file(s)
	if count of file_list is greater than 0 then
		InitiateFileProcessing(file_list)
	end if
end run

-- Handler to run when processing files (either from on run() or drag/drop)
on open(file_list)
	-- Initialize the global variables
	InitializeGlobals()

	-- Given one or more files to processing, process the file(s)
	if count of file_list is greater than 0 then
		InitiateFileProcessing(file_list)
	end if
end open

-- Prompt for password and then start processing files
on InitiateFileProcessing(file_list)
	local mode
	local user_password

	-- Ensure the application is brought to the front
	activate

	try
		-- Ensure that all items dropped are files
		if VerifyFiles(file_list) is false then
			MessageDialog("Only regular files can be processed.")
			return
		end if

		-- Decide if encrypting if any file does not end in .aes
		set mode to DetermineOperationalMode(file_list)
		if mode is equal to "" then
			return
		end if

		-- Prompt the user for a password
		set user_password to PromptPassword(mode)
		if user_password is equal to "" then
			return
		end if

		-- Iterate over all files, encrypting or decrypting as appropriate
		PerformOperations(mode, file_list, user_password)
	on error e
		MessageDialog("Unexpected error: " & (e as text))
	end try
end open

-- Show a message dialog window to the user having the specified message
on MessageDialog(message)
	display dialog message ¬
		with title "AES Crypt" ¬
		buttons "OK" ¬
		default button "OK" ¬
		with icon file (path to resource "aescrypt_lock.icns")
end MessageDialog

-- Ensure all of the given names are regular files
on VerifyFiles(file_list)
	local file_list_item
	local posix_path
	local file_type

	repeat with file_list_item in file_list
		set posix_path to quoted form of (POSIX path of file_list_item)
		set file_type to (do shell script "file -b -i " & posix_path)
		if file_type is not equal to "regular file" then
			return false
		end if
	end repeat

	return true
end VerifyFiles

-- Determine if encrypting/decrypting based on file names
-- (Any list having a file no ending in .aes triggers encryption)
on DetermineOperationalMode(file_list)
	local normal_files
	local aes_files

	set normal_files to false
	set aes_files to false

	repeat with file_list_item in file_list
		set file_extension to name extension of (info for file_list_item)
		ignoring case
			if file_extension is equal to "aes" then
				set aes_files to true
			else
				set normal_files to true
			end if
		end ignoring
	end repeat

	if normal_files is true and aes_files is true then
		MessageDialog("Cannot process both AES Crypt and non-AES Crypt " & ¬
		              "files at the same time.")
		return ""
	end if

	if normal_files is true then
		return "e"
	end if

	-- Default mode is decryption
	return "d"
end DetermineOperationalMode

-- Render the password dialog with the given message, returning the an empty
-- string on error or if the user presses "Cancel"
on PasswordDialog(message)
	local user_password

	set user_password to ""

	-- Repeatedly prompt for a password until provided or "Cancel" is pressed
	repeat while user_password is equal to ""
		try
			set user_password to text returned of ( ¬
				display dialog message with title "AES Crypt" ¬
				default answer "" ¬
				buttons {"Cancel", "OK"} ¬
				default button "OK" ¬
				with icon file (path to resource "aescrypt_lock.icns") ¬
				with hidden answer)
		on error e number error_number
			if error_number is -128 then
				-- User pressed "Cancel"
				set user_password to ""
				exit repeat
			else
				-- All other errors will render a message
				MessageDialog("Error prompting for password: " & (e as text))
				set user_password to ""
				exit repeat
			end if
		end try
		if user_password is equal to "" then
			MessageDialog("A password must be provided.")
		end if
	end repeat

	return user_password
end PasswordDialog

-- Prompts the user for a password, returning "" if the user clicks "Cancel"
on PromptPassword(mode)
	local user_password
	local verify_password

	set user_password to ""
	set verify_password to ""

	-- Loop until a password is acquired or user cancels the password prompt
	repeat while user_password is ""
		-- Textual version of the mode to show the user
		if mode is equal to "e" then
			set mode_text to "encryption"
		else
			set mode_text to "decryption"
		end if
		set message to "Enter password for " & mode_text

		-- Render the dialog box and allow for the user to cancel
		set user_password to PasswordDialog(message)
		if user_password is ""
			exit repeat
		end if

		-- If encrypting, verify the user's password
		if mode is equal to "e" then
			set verify_password to PasswordDialog("Verify the password")
			if verify_password is ""
				set user_password to ""
				exit repeat
			end if
			if verify_password is not equal to user_password then
				MessageDialog("The passwords entered do not match.")
				set user_password to ""
			end if
		end if
	end repeat

	return user_password
end PromptPassword

-- Get the user's locale information
on GetUserLocale()
	local user_locale

	try
		set user_locale to user locale of (system info)
	on error
		return ""
	end try

	return user_locale
end GetUserLocale

-- Get character encoding for AES Crypt (User's locale + UTF-8)
on GetCharacterEncoding()
	local locale_list
	local user_locale

	try
		-- Get the list of locales
		set locale_list to do shell script "locale -a"

		-- Get the user's locale from the system, assuming UTF-8 for encoding
		set user_locale to GetUserLocale() & ".UTF-8"

		-- Able to get the locale string (more than just the .UTF-8 part)?
		if user_locale is not equal to ".UTF-8" then
			-- If the user's locale is in the list, use it
			if locale_list contains user_locale then
				return user_locale
			end if
		end if

		-- Attempt to fall back to en_US.UTF-8 and use it if available
		set user_locale to "en_US.UTF-8"
		if locale_list contains user_locale then
			return user_locale
		end if
	on error
		return ""
	end try

	return ""
end GetCharacterEncoding

-- Return a shortened pathname
on ShortenedName(pathname, max_length)
	local path_length

	set path_length to length of pathname

	if path_length is less than or equal to max_length
		return pathname
	end if

	return "..." & text (path_length - max_length) through path_length of ¬
	        pathname
end ShortenedName

-- Get a temporary file
on GetTemporaryFilename()
	local temporary_folder
	local uuid

	try
		set temporary_folder to POSIX path of (path to temporary items as text)

		set uuid_string to do shell script "uuidgen"
	on error
		return "/tmp/aescrypt.tmp." & ((random number from 0 to 100000) as text)
	end try

	return temporary_folder & "AES-" & uuid_string
end GetTemporaryFilename

-- Check to see if the specified file exists
on DoesFileExist(pathname)
	global stop_requested
	local file_info
	local file_exists

	set file_exists to false

	-- Attempt up to 1 second to check for file existence
	-- (In practice, it should never take this long)
	repeat with i from 1 to 10
		try
			set file_info to info for (POSIX file pathname)
			set file_exists to true
			exit repeat
		on error e number error_number
			if error_number is -128 then
				-- User pressed cancel / stop
				set stop_requested to true
			else
				-- Other error suggest the file does not exist
				exit repeat
			end if
		end try
	end repeat

	return file_exists
end DoesFileExist

-- Remove the specified file
on RemoveFile(pathname)
	global stop_requested

	-- If the file does not exist, we're done
	if DoesFileExist(pathname) is false
		return
	end if

	-- Attempt up to 1 second to remove the file
	-- (In practice, it should never take this long)
	repeat with i from 1 to 10
		try
			do shell script "rm -f " & quoted form of pathname
			exit repeat
		on error e number error_number
			if error_number is -128 then
				-- User pressed cancel / stop
				set stop_requested to true
			else
				-- Some other error occurred, so exit
				exit repeat
			end if
		end try
	end repeat
end RemoveFile

-- Check to see if a file is empty
on IsFileEmpty(pathname)
	global stop_requested
	local file_info

	-- Attempt up to 1 second to check if a file is empty
	-- (In practice, it should never take this long)
	repeat with i from 1 to 10
		try
			set file_info to info for (POSIX file pathname)

			return (size of file_info is 0)
		on error e number error_number
			if error_number is -128 then
				-- User pressed cancel / stop
				set stop_requested to true
			else
				-- Some other error occurred, so exit
				exit repeat
			end if
		end try
	end repeat

	-- Assume the file is empty if we keep failing
	return true
end IsFileEmpty

-- Read the contents of a file
on ReadFileContent(pathname)
	global stop_requested
	local file_content

	set file_content to ""

	-- Attempt up to 1 second to read the file content
	-- (In practice, it should never take this long)
	repeat with i from 1 to 10
		try
			set file_content to do shell script "cat " & quoted form of pathname

			if file_content ends with linefeed
				set file_content to text 1 thru -2 of file_content
			end if
			exit repeat
		on error e number error_number
			if error_number is -128 then
				-- User pressed cancel / stop
				set stop_requested to true
			else
				-- Some other error occurred, so exit
				exit repeat
			end if
		end try
	end repeat

	return file_content
end ReadFileContent

-- Check for running task
on IsTaskRunning(task_id)
	global stop_requested
	local task_running
	local task_check

	set task_running to false

	-- Attempt up to 1 second to check on the task status
	-- (In practice, it should never take this long)
	repeat with i from 1 to 10
		try
			set task_check to do shell script "ps -p " & ¬
				quoted form of (task_id as text)
			if task_check contains task_id then
				set task_running to true
			end if
			exit repeat
		on error e number error_number
			if error_number is -128 then
				-- User pressed cancel / stop
				set stop_requested to true
			else
				-- Some other error occurred, so exit
				exit repeat
			end if
		end try
	end repeat

	return task_running
end IsTaskRunning

-- Handler to kill running task
on KillTask(task_id)
	local retry_count

	-- Attempt up to 1 second to kill the process before giving up
	-- (In practice, it should never take this long)
	repeat with i from 1 to 10
		try
			-- If the process is not running, break out of the loop
			if IsTaskRunning(task_id) is false then
				exit repeat
			end if

			-- Kill the task and delay termination
			do shell script "kill -s INT " & quoted form of (task_id as text)
			exit repeat
		on error e number error_number
			if error_number is -128 then
				-- User pressed cancel / stop
				set stop_requested to true
			else
				-- Some other error occurred, so exit
				exit repeat
			end if
		end try
	end repeat
end KillTask

-- Perform final cleanup
on Cleanup(processing_error, task_id, error_file)
	global stop_requested

	-- Final message depends on whether the user pressed stop or cancel
	if processing_error is true then
		set progress description to "Cleaning up..."
	else
		if stop_requested is false then
			set progress description to "Processing complete"
		else
			set progress description to "Stopping..."
		end if
	end if
	set progress additional description to ""
	delay 0.01

	-- Terminate the running process, if one is running
	if task_id is greater than 0 then
		KillTask(task_id)
	end if

	-- Remove the temporary error file
	RemoveFile(error_file)

	-- Dismiss the progress indicator
	set progress description to ""
	set progress additional description to ""
	set progress total steps to 0
	set progress completed steps to 0
end Cleanup

-- Perform encryption or decryption operations
on PerformOperations(mode, file_list, password)
	global stop_requested
	local user_locale
	local aescrypt
	local file_list_item
	local file_path
	local file_index
	local current_task
	local error_file
	local processing_error

	-- Determine the locale to use
	set user_locale to GetCharacterEncoding()
	if user_locale is equal to "" then
		MessageDialog("Unable to determine a suitable character encoding. " & ¬
					  "Contact support for assistance. (" & ¬
					  GetUserLocale() & ")")
		return
	end if

	-- Initialize some local variables
	set aescrypt to quoted form of ( ¬
		POSIX path of ((path to me as text) & "Contents:MacOS:aescrypt"))
	set error_file to GetTemporaryFilename()
	set processing_error to false
	set file_index to 0
	set current_task to 0

	-- Initialize the progress indicator
	set progress total steps to count of file_list
	set progress completed steps to 0
	if mode is "e" then
		set progress description to "Encrypting files..."
	else
		set progress description to "Decrypting files..."
	end if
	set progress additional description to ""

	try
		-- Iterate over each file, encrypting or decrypting
		repeat with file_list_item in file_list
			set file_path to POSIX path of file_list_item

			-- Update the progress indicator
			set progress additional description to ShortenedName(file_path, 64)
			set file_index to file_index + 1
			set progress completed steps to file_index

			-- Launch AES Crypt as a background task
			set current_task to do shell script ( ¬
				"LANG=" & user_locale & " nohup sh -s <<'EOF' >/dev/null 2>" & ¬
				quoted form of error_file & " &\n" & ¬
				"PASS=" & quoted form of password & "\n" & ¬
				"exec " & aescrypt & " -q -" & mode & " -k - " & ¬
				quoted form of file_path & " <<< \"$PASS\"; unset PASS\n" & ¬
				"EOF\n" & ¬
				"echo $!")

			-- Wait for the AES Crypt process to complete
			repeat
				delay 0.05
				if IsTaskRunning(current_task) is false or ¬
				   stop_requested is true then
					exit repeat
				end if
			end repeat

			-- Task completed, so clear state and check for errors
			set current_task to 0
			if DoesFileExist(error_file) is true and ¬
			   IsFileEmpty(error_file) is false then
				set processing_error to true
				MessageDialog(ReadFileContent(error_file))
				exit repeat
			end if

			-- Was there a request to stop?
			if stop_requested is true then
				exit repeat
			end if
		end repeat

		-- Perform final cleanup
		Cleanup(processing_error, current_task, error_file)
	on error e number error_number
		if error_number is -128 then
			-- User pressed cancel / stop
			set stop_requested to true
			Cleanup(processing_error, current_task, error_file)
		else
			MessageDialog(e as text)
			Cleanup(processing_error, current_task, error_file)
		end if
	end try
end PerformOperations
