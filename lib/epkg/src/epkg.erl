%%%-------------------------------------------------------------------
%%% @author Martin Logan 
%%% @doc The interface module for all user level epkg functions. Application programmers may want to use the lower level 
%%%      libraries in order to avoid output to stdout and other such UI concerns. 
%%% 
%%% @end
%%% @copyright (C) 2007, Martin Logan, Eric Merritt, Erlware
%%%-------------------------------------------------------------------
-module(epkg).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
-export([
	 install_release/1,
	 install_erts/1,
	 install_app/1,
	 install/1,
	 list/0,
	 list_lib/0,
	 list_releases/0,
	 remove_all_apps/1,
	 remove_app/2,
	 remove_all/1,
	 remove/2,
	 version/0,
	 help/0,
	 help/1
	]).

-export([
	 install_release_help/0,
	 install_app_help/0,
	 install_help/0,
	 install_erts_help/0,
	 list_help/0,
	 remove_app_help/0,
	 remove_all_apps_help/0,
	 remove_help/0,
	 remove_all_help/0,
	 examples_help/0,
	 commands_help/0
	]).

%%====================================================================
%% API
%%====================================================================

%%--------------------------------------------------------------------
%% @doc 
%%  Determine the type of a package and then install it appropriately. 
%% @spec install(RelPackagePath) -> ok | {error, Reason}
%% where
%%  Reason = badly_formatted_or_missing_package | {failed_to_install, [{AppName, AppVsn}]}
%% @end
%%--------------------------------------------------------------------
install(PackageDirOrArchive) -> 
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    PackageDirPath         = epkg_util:unpack_to_tmp_if_archive(PackageDirOrArchive), 
    case epkg_validation:validate_type(PackageDirPath) of
	binary  -> epkg_install:install_application(PackageDirPath, InstallationPath);
	generic -> epkg_install:install_application(PackageDirPath, InstallationPath);
	release -> epkg_install:install_release(PackageDirPath, InstallationPath, false);
	erts    -> epkg_install:install_erts(PackageDirPath, InstallationPath);
	Error   -> Error
    end.

%% @private
install_help() ->
    ["\nHelp for install\n",
     "Usage: install <package_path>: Install a release from a local package\n"]. 

%%--------------------------------------------------------------------
%% @doc 
%%  Install a release package or package archive.
%% @spec install_release(RelPackagePath) -> ok | {error, Reason}
%% where
%%  Reason = badly_formatted_or_missing_release_package | {failed_to_install, [{AppName, AppVsn}]}
%% @end
%%--------------------------------------------------------------------
install_release(RelPackagePath) -> 
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    epkg_install:install_release(RelPackagePath, InstallationPath, false).

%% @private
install_release_help() ->
    ["\nHelp for install-release\n",
     "Usage: install-release <package_path>: Install an release from a local package\n"]. 

%%--------------------------------------------------------------------
%% @doc 
%%  Install an application package or package archive.
%% @spec install_app(AppPackagePath) -> ok | {error, Reason}
%% where
%%  Reason = badly_formatted_or_missing_app_package
%% @end
%%--------------------------------------------------------------------
install_app(AppPackagePath) -> 
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    epkg_install:install_application(AppPackagePath, InstallationPath).

%% @private
install_app_help() ->
    ["\nHelp for install-app\n",
     "Usage: install-app <package_path>: Install an application from a local package\n"]. 

%%--------------------------------------------------------------------
%% @doc 
%%  Install an erts package or archive. 
%% @spec install_erts(ErtsPackagePath) -> ok | {error, Reason}
%% where
%%  Reason = badly_formatted_or_missing_erts_package | {failed_to_install, [{AppName, AppVsn}]}
%% @end
%%--------------------------------------------------------------------
install_erts(ErtsPackagePath) -> 
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    epkg_install:install_erts(ErtsPackagePath, InstallationPath).

%% @private
install_erts_help() ->
    ["\nHelp for install-erts\n",
     "Usage: install-erts <package_path>: Install an erts from a local package\n"]. 

%%--------------------------------------------------------------------
%% @doc 
%%  Returns a list of all OTP packages currently installed.
%% @spec list() -> string()
%% @end
%%--------------------------------------------------------------------
list() ->
    list_lib(),
    list_releases().

%% @private
list_help() ->
    ["\nHelp for list\n",
     "Usage: list: list all installed packages\n"]. 

%%--------------------------------------------------------------------
%% @doc 
%%  Returns a list of all applications currently installed.
%% @spec list_lib() -> string()
%% @end
%%--------------------------------------------------------------------
list_lib() ->
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    NameVsnPairs = epkg_manage:list_lib(InstallationPath),
    io:format("~nInstalled Applications:~n"),
    lists:foreach(fun({Name, Vsn}) -> io:format("~s   ~s~n", [Name, Vsn]) end, NameVsnPairs).

%%--------------------------------------------------------------------
%% @doc 
%%  Returns a list of all releases currently installed.
%% @spec list_releases() -> string()
%% @end
%%--------------------------------------------------------------------
list_releases() ->
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    NameVsnPairs = epkg_manage:list_releases(InstallationPath),
    io:format("~nInstalled Applications:~n"),
    lists:foreach(fun({Name, Vsn}) -> io:format("~s   ~s~n", [Name, Vsn]) end, NameVsnPairs).

%%--------------------------------------------------------------------
%% @doc 
%%  Remove an installed application.
%% @spec remove_app(AppName, AppVsn) -> ok
%%  where
%%   AppName = string()
%%   AppVsn = string()
%% @end
%%--------------------------------------------------------------------
remove_app(AppName, AppVsn) ->
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    [A, B]                 = epkg_util:if_atom_or_integer_to_string([AppName, AppVsn]),
    epkg_manage:remove_app(InstallationPath, A, B).

%% @private
remove_app_help() ->
    ["\nHelp for remove_app\n",
     "Usage: remove-app <app name> <app version>: remove a particular for a particular version.\n",
     "Example: remove-app tools 2.4.5 - removes version 2.4.5 of the tools application."].

%%--------------------------------------------------------------------
%% @doc 
%%  Remove all versions of an installed application.
%% @spec remove_all_apps(AppName) -> ok
%%  where
%%   AppName = string()
%% @end
%%--------------------------------------------------------------------
remove_all_apps(AppName) ->
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    epkg_manage:remove_all_apps(InstallationPath, epkg_util:if_atom_or_integer_to_string(AppName)).
			  
%% @private
remove_all_apps_help() ->
    ["\nHelp for remove_all_apps\n",
     "Usage: remove-all-app <app name>: remove a particular application for all versions installed.\n",
     "Example: remove-all-app tools - removes all versions of the tools application currently installed."].
   

%%--------------------------------------------------------------------
%% @doc 
%%  Remove an installed release.
%% @spec remove(RelName, RelVsn) -> ok 
%%  where
%%   RelName = string()
%%   RelVsn = string()
%% @end
%%--------------------------------------------------------------------
remove(RelName, RelVsn) ->
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    [A, B]                 = epkg_util:if_atom_or_integer_to_string([RelName, RelVsn]),
    epkg_manage:remove_release(InstallationPath, A, B, false).
    
%% @private
remove_help() ->
    ["\nHelp for remove\n",
     "Usage: remove <release-name> <release-version>: remove a particular for a particular version.\n",
     "Example: remove faxien 0.8.6 - removes version 0.8.6 of the sinan release."].

%%--------------------------------------------------------------------
%% @doc 
%%  Remove all versions of an installed release.
%% @spec remove_all(RelName) -> ok
%%  where
%%   RelName = string()
%% @end
%%--------------------------------------------------------------------
remove_all(RelName) ->
    {ok, InstallationPath} = epkg_installed_paths:get_installation_path(),
    epkg_manage:remove_all_releases(InstallationPath, epkg_util:if_atom_or_integer_to_string(RelName), false).

%% @private
remove_all_help() ->
    ["\nHelp for remove_all\n",
     "Usage: remove-all <release-name>: remove a particular rlease for all versions installed.\n",
     "Example: remove-all sinan - removes all versions of the sinan release that are currently installed."].

%%--------------------------------------------------------------------
%% @doc 
%%  Return the version of the current Epkg release.
%% @spec version() -> string()
%% @end
%%--------------------------------------------------------------------
version() -> 
    {value, {epkg, _, Vsn}} = lists:keysearch(epkg, 1, application:which_applications()),
    {ok, Vsn}.

%%--------------------------------------------------------------------
%% @doc 
%%  Print the help screen
%% @spec help() -> ok
%% @end
%%--------------------------------------------------------------------
help() -> 
    print_help_list(
      [
       "\nEpkg is a powerful package manager and the backbone of Faxien. This message is the gateway into further Epkg help.",
       "\nUsage:",
       "epkg help",
       "epkg version",
       "epkg <command> [options|arguments...]",
       "\nMore Help:",
       "epkg help commands: Lists all epkg commands",
       "epkg help <command>: Gives help on an individual command",
       "epkg help examples: Lists example usages of epkg",
       "\nShort Examples:",
       "epkg install sinan",
       "epkg list",
       "epkg help install"
      ]).  

%% @private
examples_help() ->
    [
     "\nExamples:",
     "\nInstall the tools application from the local filesystem", 
     "  epkg install /usr/local/erlang/lib/tools-2.5.4",
     "\nInstall a new version of epkg from a release tarball", 
     "  epkg install epkg-0.19.3.tar.gz"
    ].

%% @private
commands_help() ->
    [
     "\nCommands:",
     "help                    print help information",
     "list                    list the packages installed on the local system",
     "install                 install a release package",
     "remove-app              uninstall a particular version of an application package",
     "remove-all-apps         uninstall all versions of an application package",
     "remove                  uninstall a particular version of a release package",
     "remove-all              uninstall all versions of a release package",
     "version                 display the current Faxien version installed on the local system"
    ].


%%--------------------------------------------------------------------
%% @doc 
%%  Print the help screen for a specific command.
%% @spec help(Command::atom()) -> ok
%% @end
%%--------------------------------------------------------------------
help(Command) when is_atom(Command) ->
    help_for_command(Command).

%%====================================================================
%% Internal functions
%%====================================================================

help_for_command(Command) ->
    StrCommand = atom_to_list(Command),
    Func       = list_to_atom(StrCommand ++ "_help"),
    case catch ?MODULE:Func() of
	{'EXIT', _Reason} ->
	    io:format("That command does not have detailed help associated with it~n");
	HelpList -> 
	    print_help_list(HelpList) 
    end.

print_help_list(HelpList) ->	   
    lists:foreach(fun(HelpString) -> io:format("~s~n", [HelpString]) end, HelpList).
    