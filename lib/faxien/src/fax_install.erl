%%%-------------------------------------------------------------------
%%% @doc Handles fetching packages from the remote repository and 
%%%      placing them in the erlware repo.
%%%
%%% @type force() = bool(). Indicates whether an existing app is to be overwritten with or without user conscent.  
%%%
%%% @todo add the force option to local installs in epkg
%%% @todo add explicit timeouts to every interface function depricate the macro or use it as a default in the faxien module. 
%%%
%%% @author Martin Logan
%%% @copyright Erlware
%%% @end
%%%-------------------------------------------------------------------
-module(fax_install).

%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------
-include("faxien.hrl").

%%--------------------------------------------------------------------
%% External exports
%%--------------------------------------------------------------------
-export([
	 install_latest_remote_application/5,
	 install_remote_application/6,
	 install_latest_remote_release/6,
	 install_remote_release/7,
	 install_remote_erts/3,
	 install_application/5,
	 install_erts/3,
	 install_release/6
	]).

%%====================================================================
%% External functions
%%====================================================================

%%--------------------------------------------------------------------
%% @doc 
%%  Install an application package.  This function will determine whether the target (AppNameOrPath) is a request to install
%%  an application from a remote repository or to install a tared up release package (.tar.gz) or an untarred package directory.
%%
%% @spec install_application(Repos, TargetErtsVsn, AppNameOrPath, Force, Timeout) -> ok | {error, Reason} | exit()
%% where
%%     Type = application | release
%%     AppNameOrPath = string()
%%     Force = force()
%% @end
%%--------------------------------------------------------------------
install_application(Repos, TargetErtsVsn, AppNameOrPath, Force, Timeout) ->
    case filelib:is_file(AppNameOrPath) of
	true  -> epkg:install_app(AppNameOrPath);
	false -> install_latest_remote_application(Repos, TargetErtsVsn, AppNameOrPath, Force, Timeout)
    end.

%%--------------------------------------------------------------------
%% @doc 
%%  Install a the highest version found of an application package from a repository. 
%%
%% <pre>
%% Examples:
%%  install_latest_remote_application(["http"//repo.erlware.org/pub"], "5.5.5", gas)
%% </pre>
%%
%% @spec install_latest_remote_application(Repos, TargetErtsVsn, AppName, Force, Timeout) -> ok | {error, Reason} | exit()
%% where
%%     Repos = string()
%%     TargetErtsVsn = string()
%%     AppName = string()
%%     Force = force()
%% @end
%%--------------------------------------------------------------------
install_latest_remote_application(Repos, TargetErtsVsn, AppName, Force, Timeout) ->
    Fun = fun(ManagedRepos, AppVsn) ->
		  install_remote_application(ManagedRepos, TargetErtsVsn, AppName, AppVsn, Force, Timeout)
	  end,
    fax_util:execute_on_latest_package_version(Repos, TargetErtsVsn, AppName, Fun, lib). 

%%--------------------------------------------------------------------
%% @doc 
%%  Install an application package from a repository. Versions can be the string "LATEST". Calling this function will install 
%%  a remote application at IntallationPath/lib/Appname-Appvsn.
%%
%% <pre>
%% Examples:
%%  install_remote_application(["http"//repo.erlware.org/pub"], "5.5.5", gas, "4.6.0", false)
%% </pre>
%%
%% @spec install_remote_application(Repos, TargetErtsVsn, AppName, AppVsn, Force, Timeout) -> ok | {error, Reason} | exit()
%% where
%%     Repos = string()
%%     TargetErtsVsn = string()
%%     AppName = string()
%%     AppVsn = string() 
%%     Force = bool()
%% @end
%%--------------------------------------------------------------------
install_remote_application(Repos, TargetErtsVsn, AppName, AppVsn, Force, Timeout) ->
    ?INFO_MSG("install_remote_application(~p, ~p, ~p, ~p)~n", [Repos, TargetErtsVsn, AppName, AppVsn]),
    AppDir = epkg_installed_paths:installed_app_dir_path(AppName, AppVsn),
    case epkg_validation:is_package_an_app(AppDir) of
	false -> 
	    io:format("Pulling down ~s-~s -> ", [AppName, AppVsn]),
	    {ok, AppPackageDirPath} = fetch_app(Repos, TargetErtsVsn, AppName, AppVsn, Timeout),
	    Res                     = epkg:install_app(AppPackageDirPath),
	    ok                      = ewl_file:delete_dir(AppPackageDirPath),
	    io:format("~p~n", [Res]),
	    Res;
	true -> 
	    epkg_util:overwrite_yes_no(
	      fun() -> install_remote_application(Repos, TargetErtsVsn, AppName, AppVsn, Force, Timeout) end,  
	      fun() -> ok end, 
	      AppDir, 
	      Force)
    end.

%%--------------------------------------------------------------------
%% @doc 
%%  Install an erts package. 
%% @spec install_erts(Repos, ErtsVsnOrPath, Timeout) -> ok | {error, Reason} | exit()
%% where
%%     Type = application | release
%%     AppNameOrPath = string()
%% @end
%%--------------------------------------------------------------------
install_erts(Repos, ErtsVsnOrPath, Timeout) ->
    case filelib:is_file(ErtsVsnOrPath) of
	true  -> epkg:install_erts(ErtsVsnOrPath);
	false -> install_remote_erts(Repos, ErtsVsnOrPath, Timeout)
    end.
	    
%%--------------------------------------------------------------------
%% @doc 
%%  Install an erts package from a repository. 
%% <pre>
%% Examples:
%%  install_remote_erts(["http"//repo.erlware.org/pub"], "5.5.5", 100000)
%% </pre>
%% @spec install_remote_erts(Repos, ErtsVsn, Timeout) -> ok | {error, Reason} | exit()
%% where
%%     Repos = string()
%%     TargetErtsVsn = string()
%%     ErtsName = string()
%%     ErtsVsn = string() 
%% @end
%%--------------------------------------------------------------------
install_remote_erts(Repos, ErtsVsn, Timeout) ->
    ?INFO_MSG("install_remote_erts(~p, ~p)~n", [Repos, ErtsVsn]),
    ErtsDir = epkg_installed_paths:installed_erts_path(ErtsVsn),
    case epkg_validation:is_package_erts(ErtsDir) of
	false -> 
	    io:format("Pulling down erts-~s -> ", [ErtsVsn]),
	    ErtsPackageDirPath = fetch_erts(Repos, ErtsVsn, Timeout),
	    Res                = epkg:install_erts(ErtsPackageDirPath),
	    ok                 = ewl_file:delete_dir(ErtsPackageDirPath),
	    io:format("~p~n", [Res]),
	    Res;
	true -> 
	    ok
    end.

%%--------------------------------------------------------------------
%% @doc 
%%  Install a release package.  This function will determine whether the target (AppNameOrPath) is a request to install
%%  an application from a remote repository or to install a tared up release package (.tar.gz) or an untarred package directory.
%%  IsLocalBoot indicates whether a local specific boot file is to be created or not. See the systools docs for more information.
%% @spec install_release(Repos, TargetErtsVsn, ReleasePackageArchiveOrDirPath, IsLocalBoot, Force, Timeout) -> ok | {error, Reason} | exit()
%% where
%%     Type = application | release
%%     AppNameOrPath = string()
%%     ReleasePackageArchiveOrDirPath = string()
%%     IsLocalBoot = bool()
%%     Force = force()
%% @end
%%--------------------------------------------------------------------
install_release(Repos, TargetErtsVsn, ReleasePackageArchiveOrDirPath, IsLocalBoot, Force, Timeout) ->
    case filelib:is_file(ReleasePackageArchiveOrDirPath) of
	true  -> install_from_local_release_package(Repos, ReleasePackageArchiveOrDirPath, IsLocalBoot, Force, Timeout);
	false -> install_latest_remote_release(Repos, TargetErtsVsn, ReleasePackageArchiveOrDirPath, IsLocalBoot, Force, Timeout)
    end.
				  
%%--------------------------------------------------------------------
%% @doc 
%%  Install the latest version found of a release package from a repository. 
%%  IsLocalBoot indicates whether a local specific boot file is to be created or not. See the systools docs for more information.
%% @spec install_latest_remote_release(Repos, TargetErtsVsn, RelName, IsLocalBoot, Force, Timeout) -> 
%%               ok | {error, Reason} | exit()
%% where
%%     Repos = string()
%%     RelName = string()
%%     RelVsn = string() 
%%     IsLocalBoot = bool()
%%     Force = force()
%% @end
%%--------------------------------------------------------------------
install_latest_remote_release(Repos, TargetErtsVsn, RelName, IsLocalBoot, Force, Timeout) ->
    Fun = fun(ManagedRepos, RelVsn) ->
		  install_remote_release(ManagedRepos, TargetErtsVsn, RelName, RelVsn, IsLocalBoot, Force, Timeout)
	  end,
    fax_util:execute_on_latest_package_version(Repos, TargetErtsVsn, RelName, Fun, releases). 

%%--------------------------------------------------------------------
%% @doc 
%%  Install a release package from a repository. 
%%  IsLocalBoot indicates whether a local specific boot file is to be created or not. See the systools docs for more information.
%% @spec install_remote_release(Repos, TargetErtsVsn, RelName, RelVsn, IsLocalBoot, Force, Timeout) -> ok | {error, Reason} | exit()
%% where
%%     Repos = string()
%%     RelName = string()
%%     RelVsn = string() 
%%     IsLocalBoot = bool()
%%     Force = force()
%% @end
%%--------------------------------------------------------------------
install_remote_release(Repos, TargetErtsVsn, RelName, RelVsn, IsLocalBoot, Force, Timeout) ->
    ?INFO_MSG("(~p, ~p, ~p, ~p, ~p, ~p)~n", [Repos, TargetErtsVsn, RelName, RelVsn, IsLocalBoot]),
    ReleaseDir = epkg_installed_paths:installed_release_dir_path(RelName, RelVsn),
    case epkg_validation:is_package_a_release(ReleaseDir) of
	false -> 
	    io:format("~nInitiating Install for Remote Release ~s-~s~n", [RelName, RelVsn]),
	    {ok, ReleasePackageDirPath} = fetch_release(Repos, TargetErtsVsn, RelName, RelVsn, Timeout),
	    Res = install_from_local_release_package(Repos, ReleasePackageDirPath, IsLocalBoot, Force, Timeout),
	    io:format("Installation of ~s-~s resulted in ~p~n", [RelName, RelVsn, Res]),
	    Res;
	true -> 
	    epkg_util:overwrite_yes_no(
	      fun() -> install_remote_release(Repos, TargetErtsVsn, RelName, RelVsn, IsLocalBoot, Force, Timeout) end,  
	      fun() -> ok end, 
	      ReleaseDir, 
	      Force)
    end.


%%====================================================================
%% Internal functions Containing Business Logic
%%====================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc Install a release from a local package.  If all required app files are not present go out and fetch then and then 
%%      try again.
%% @end
%%--------------------------------------------------------------------
install_from_local_release_package(Repos, ReleasePackageArchiveOrDirPath, IsLocalBoot, Force, Timeout) ->
    %% @todo think about continuing to pass IsLocalBoot from faxien to epkg
    
    ReleasePackageDirPath   = epkg_util:unpack_to_tmp_if_archive(ReleasePackageArchiveOrDirPath),
    {ok, {RelName, RelVsn}} = epkg_installed_paths:package_dir_to_name_and_vsn(ReleasePackageDirPath),
    RelFilePath             = epkg_package_paths:release_package_rel_file_path(ReleasePackageDirPath, RelName, RelVsn),
    TargetErtsVsn           = epkg_util:consult_rel_file(erts_vsn, RelFilePath),
    
    case catch epkg:install_release(ReleasePackageDirPath) of
	{error, {failed_to_install, AppAndVsns}} ->
	    %% The release package did not contain all the applications required.  Pull them down, install them, and try again.
	    lists:foreach(fun({AppName, AppVsn}) ->
				  install_remote_application(Repos, TargetErtsVsn, AppName, AppVsn, Force, Timeout)
			  end, AppAndVsns),
	    install_from_local_release_package(Repos, ReleasePackageDirPath, IsLocalBoot, Force, Timeout);
	
	{error, badly_formatted_or_missing_erts_package} ->
	    %% The release package did not contain the appropriate erts package, and it is not already installed, pull it down
	    %% install it and try again.
	    ok = install_remote_erts(Repos, TargetErtsVsn, Timeout),
	    install_from_local_release_package(Repos, ReleasePackageDirPath, IsLocalBoot, Force, Timeout);
	
	Other ->
	    ?INFO_MSG("exited release install on a local package with ~p~n", [Other]),
	    Other
    end.

%%====================================================================
%% Internal functions
%%====================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc pull down an application from a repo and return the path to the temp directory where the package was put locally.
%% @spec fetch_app(Repos, TargetErtsVsn, AppName, AppVsn, Timeout) -> {ok, AppPackageDirPath} | {error, Reason}
%% @end
%%--------------------------------------------------------------------
fetch_app(Repos, TargetErtsVsn, AppName, AppVsn, Timeout) ->
    try
	AppDir              = epkg_installed_paths:installed_app_dir_path(AppName, AppVsn),
	ok                  = ewl_file:delete_dir(AppDir),
	{ok, TmpPackageDir} = epkg_util:create_unique_tmp_dir(),
	ok = fax_util:foreach_erts_vsn(TargetErtsVsn, 
				       fun(ErtsVsn_) -> 
					       ewr_fetch:fetch_binary_package(Repos, ErtsVsn_, AppName, AppVsn, 
									      TmpPackageDir, Timeout)
				       end),
	AppPackageDirPath = epkg_package_paths:package_dir_path(TmpPackageDir, AppName, AppVsn),
	{ok, AppPackageDirPath}
    catch
	_Class:_Exception = {badmatch, {error, _} = Error} ->
	    Error
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc pull down an erts package from a repo and return the path to the temp directory where the package was put locally.
%% @spec fetch_erts(Repos, TargetErtsVsn, Timeout) -> ok | {error, Reason}
%% @end
%%--------------------------------------------------------------------
fetch_erts(Repos, ErtsVsn, Timeout) ->
    try
	ErtsDir             = epkg_installed_paths:installed_erts_path(ErtsVsn),
	ok                  = ewl_file:delete_dir(ErtsDir),
	{ok, TmpPackageDir} = epkg_util:create_unique_tmp_dir(),
	ok                  = ewr_fetch:fetch_erts_package(Repos, ErtsVsn, TmpPackageDir, Timeout),
	ErtsPackageDirPath  = epkg_package_paths:package_dir_path(TmpPackageDir, "erts", ErtsVsn),
	{ok, ErtsPackageDirPath}
    catch
	_Class:_Exception = {badmatch, {error, _} = Error} ->
	    Error
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc pull down a release from a repo.
%% @spec fetch_release(Repos, TargetErtsVsn, RelName, RelVsn, Timeout) -> {ok, ReleasePackageDirPath} | {error, Reason}
%% @end
%%--------------------------------------------------------------------
fetch_release(Repos, TargetErtsVsn, RelName, RelVsn, Timeout) ->
    try
	ReleaseDirPath      = epkg_installed_paths:installed_release_dir_path(RelName, RelVsn),
	ok                  = ewl_file:delete_dir(ReleaseDirPath),
	{ok, TmpPackageDir} = epkg_util:create_unique_tmp_dir(),
	ok = fax_util:foreach_erts_vsn(TargetErtsVsn, 
				       fun(ErtsVsn) -> 
					       ewr_fetch:fetch_release_package(Repos, ErtsVsn, RelName, 
									       RelVsn, TmpPackageDir, Timeout)
				       end),
	ReleasePackageDirPath = epkg_package_paths:package_dir_path(TmpPackageDir, RelName, RelVsn),
	{ok, ReleasePackageDirPath}
    catch
	_Class:_Exception = {badmatch, {error, _} = Error} ->
	    Error
    end.