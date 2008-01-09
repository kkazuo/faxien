
%%%-----------------------------------------------------------------
%%% @doc Handles fetching packages from the remote repository and 
%%%      placing them in the erlware repo.
%%% 
%%% @type force() = bool(). Indicates whether an existing app is to be overwritten with or without user conscent.  
%%%
%%% @type repo() = string(). Contains address and repo designation. 
%%%   Example: http://www.erlware.org/stable   
%%%
%%% @type timeout() = integer() | infinity. Timeouts are specified in milliseconds.
%%%
%%% @copyright 2007 Erlware
%%% @author Martin Logan
%%% @end
%%%-------------------------------------------------------------------
-module(fax_manage).

%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------
-include("eunit.hrl").
-include("faxien.hrl").


%%--------------------------------------------------------------------
%% External exports
%%--------------------------------------------------------------------
-export([
	 outdated_applications/3,
	 upgrade_applications/4,
	 upgrade_application/5,
	 outdated_releases/3,
	 upgrade_releases/5,
	 upgrade_release/6,
	 add_repo_to_publish_to/2,
	 remove_repo_to_publish_to/2,
	 add_repo_to_fetch_from/2,
	 remove_repo_to_fetch_from/2,
	 set_request_timeout/2,
	 search/4,
	 describe_app/5,
	 describe_latest_app/4
	]).

%%--------------------------------------------------------------------
%% Macros
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Records
%%--------------------------------------------------------------------

%%====================================================================
%% External functions
%%====================================================================


%%--------------------------------------------------------------------
%% @doc 
%%  Fetch the description for the latest version of a particular application from a remote repository.
%% @spec describe_latest_app(Repos, TargetErtsVsn, AppName, Timeout) -> ok | {error, Reason} | exit()
%%  where
%%   Repos = list()
%%   TargetErtsVsn = string()
%%   AppName = string()
%%   Timeout = Milliseconds::integer() | infinity
%% @end
%%--------------------------------------------------------------------
describe_latest_app(Repos, TargetErtsVsn, AppName, Timeout) ->
    Fun = fun(ManagedRepos, AppVsn) ->
		  describe_app(ManagedRepos, TargetErtsVsn, AppName, AppVsn, Timeout)
	  end,
    fax_util:execute_on_latest_package_version(Repos, TargetErtsVsn, AppName, Fun, lib). 

%%--------------------------------------------------------------------
%% @doc 
%%  Fetch the description for a particular application from a remote repository.
%% @spec describe_app(Repos, TargetErtsVsn, AppName, AppVsn, Timeout) -> ok | {error, Reason} | exit()
%%  where
%%   Repos = list()
%%   TargetErtsVsn = string()
%%   AppName = string()
%%   AppVsn = string()
%%   Timeout = Milliseconds::integer() | infinity
%% @end
%%--------------------------------------------------------------------
describe_app(Repos, TargetErtsVsn, AppName, AppVsn, Timeout) ->
    Fun = fun(ErtsVsn) -> 
		  Suffix = ewr_repo_paths:dot_app_file_suffix(ErtsVsn, AppName, AppVsn),
		  fs_lists:do_until(
		    fun(Repo) ->
			    case ewr_util:repo_consult(Repo, Suffix, Timeout) of
				{ok, {application, _, Terms}} -> 
				    io:format("~nDescribing Application: ~s~n~n ~p~n", [AppName, Terms]);
				Error ->
				    ?ERROR_MSG("consulting ~s with suffix ~s returns ~p~n", [Repo, Suffix, Error]),
				    Error
			    end
		    end, ok, Repos)
	  end,
    ok = fax_util:foreach_erts_vsn(TargetErtsVsn, Fun).

%%--------------------------------------------------------------------
%% @doc Add a repository to fetch from. 
%% @spec add_repo_to_fetch_from(Repo, ConfigFilePath) -> ok | {error, Reason}
%%  where
%%   Repos = string()
%%   ConfigFilePath = string()
%% @end
%%--------------------------------------------------------------------
add_repo_to_fetch_from(Repo, ConfigFilePath) ->
    add_to_config_list(repos_to_fetch_from, Repo, ConfigFilePath).

%%--------------------------------------------------------------------
%% @doc Remove a repository to fetch from. 
%% @spec remove_repo_to_fetch_from(Repo, ConfigFilePath) -> ok
%%  where
%%   Repos = string()
%%   ConfigFilePath = string()
%% @end
%%--------------------------------------------------------------------
remove_repo_to_fetch_from(Repo, ConfigFilePath) ->
    remove_from_config_list(repos_to_fetch_from, Repo, ConfigFilePath).

%%--------------------------------------------------------------------
%% @doc Add a repository to publish to. 
%% @spec add_repo_to_publish_to(Repo, ConfigFilePath) -> ok | {error, Reason}
%%  where
%%   Repos = string()
%%   ConfigFilePath = string()
%% @end
%%--------------------------------------------------------------------
add_repo_to_publish_to(Repo, ConfigFilePath) ->
    add_to_config_list(repos_to_publish_to, Repo, ConfigFilePath).

%%--------------------------------------------------------------------
%% @doc Remove a repository to publish to. 
%% @spec remove_repo_to_publish_to(Repo, ConfigFilePath) -> ok
%%  where
%%   Repos = string()
%%   ConfigFilePath = string()
%% @end
%%--------------------------------------------------------------------
remove_repo_to_publish_to(Repo, ConfigFilePath) ->
    remove_from_config_list(repos_to_publish_to, Repo, ConfigFilePath).

%%--------------------------------------------------------------------
%% @doc Set the request timeout.
%% @spec set_request_timeout(Timeout, ConfigFilePath) -> ok | {error, Reason}
%%  where
%%   Timeout = timeout()
%%   ConfigFilePath = string()
%% @end
%%--------------------------------------------------------------------
%% TODO set up the gas functions so that they will insert a config entry if none exists.
set_request_timeout(Timeout, ConfigFilePath) ->
    gas:modify_config_file(ConfigFilePath, faxien, request_timeout, Timeout).

%%--------------------------------------------------------------------
%% @doc Display all currently installed releases that have available updates.
%% @spec outdated_releases(Repos, TargetErtsVsn, Timeout) -> OutdatedReleases
%%  where
%%   Repos = [string()]
%%   TargetErtsVsn = string()
%%   OutdatedReleases = [{ReleaseName, HighestLocalVsn, HigherVersion}]
%% @end
%%--------------------------------------------------------------------
outdated_releases(Repos, TargetErtsVsn, Timeout) ->
    TargetErtsVsn = ewr_util:erts_version(),
    Releases      = epkg_installed_paths:list_releases(),
    lists:foldl(fun(ReleaseName, Acc) -> 
			case catch is_outdated_release(Repos, TargetErtsVsn, ReleaseName, Timeout) of
			    {ok, {lower, HighestLocalVsn, HighestRemoteVsn}} -> 
				[{ReleaseName, HighestLocalVsn, HighestRemoteVsn}|Acc];
			    _Other -> 
				Acc
			end
		end, [], Releases).

%%--------------------------------------------------------------------
%% @doc upgrade all applications on the install path.
%% @spec upgrade_releases(Repos, TargetErtsVsn, IsLocalBoot, Force, Timeout) -> ok | {error, Reason}
%%  where
%%   Repos = [string()]
%%   TargetErtsVsn = string()
%%   Force = force()
%% @end
%%--------------------------------------------------------------------
upgrade_releases(Repos, TargetErtsVsn, IsLocalBoot, Force, Timeout) ->
    TargetErtsVsn = ewr_util:erts_version(),
    Releases      = epkg_installed_paths:list_releases(),
    lists:foreach(fun(ReleaseName) -> 
			  upgrade_release(Repos, TargetErtsVsn, ReleaseName, IsLocalBoot, Force, Timeout)
		  end, Releases).

%%--------------------------------------------------------------------
%% @doc upgrade a single release.
%%  IsLocalBoot indicates whether a local specific boot file is to be created or not. See the systools docs for more information.
%% @spec upgrade_release(Repos, TargetErtsVsn, ReleaseName, IsLocalBoot, Force, Timeout) -> ok | {error, Reason}
%%  where
%%   Repos = [string()]
%%   TargetErtsVsn = string()
%%   ReleaseName = string()
%%   Force = force()
%% @end
%%--------------------------------------------------------------------
upgrade_release(Repos, TargetErtsVsn, ReleaseName, IsLocalBoot, Force, Timeout) -> 
    ?INFO_MSG("fax_manage:upgrade_release(~p, ~p, ~p)~n", [Repos, ReleaseName]),
    case is_outdated_release(Repos, TargetErtsVsn, ReleaseName, Timeout) of
	{ok, {lower, HighestLocalVsn, HighestRemoteVsn}} ->
	    io:format("Upgrading from version ~s of ~s to version ~s~n", [HighestLocalVsn, ReleaseName, HighestRemoteVsn]),
	    fax_install:install_remote_release(Repos, TargetErtsVsn, ReleaseName, HighestRemoteVsn, IsLocalBoot, Force, Timeout); 
	{ok, {_, HighestLocalVsn}} ->
	    io:format("~s at version ~s is up to date~n", [ReleaseName, HighestLocalVsn]);
	Error ->
	    io:format("~p~n", [Error]),
	    Error
    end.

%%--------------------------------------------------------------------
%% @doc Display all currently installed applications that have available updates.
%% @spec outdated_applications(Repos, TargetErtsVsn, Timeout) -> OutdatedApps
%%  where
%%   Repos = [string()]
%%   TargetErtsVsn = string()
%%   OutdatedApps = [{AppName, HighestLocalVsn, HigherVersion}]
%% @end
%%--------------------------------------------------------------------
outdated_applications(Repos, TargetErtsVsn, Timeout) ->
    TargetErtsVsn = ewr_util:erts_version(),
    Apps          = epkg_installed_paths:list_apps(),
    lists:foldl(fun(AppName, Acc) -> 
			case catch is_outdated_app(Repos, TargetErtsVsn, AppName, Timeout) of
			    {ok, {lower, HighestLocalVsn, HighestRemoteVsn}} -> 
				[{AppName, HighestLocalVsn, HighestRemoteVsn}|Acc];
			    _Other -> 
				Acc
			end
		end, [], Apps).


%%--------------------------------------------------------------------
%% @doc upgrade all applications on the install path.
%% @spec upgrade_applications(Repos, TargetErtsVsn, Force, Timeout) -> ok | {error, Reason}
%%  where
%%   Repos = [string()]
%%   TargetErtsVsn = string()
%%   Force = force()
%% @end
%%--------------------------------------------------------------------
upgrade_applications(Repos, TargetErtsVsn, Force, Timeout) -> 
    TargetErtsVsn = ewr_util:erts_version(),
    AppNames      = epkg_installed_paths:list_apps(),
    lists:foreach(fun(AppName) -> upgrade_application(Repos, TargetErtsVsn, AppName, Force, Timeout) end, AppNames).

%%--------------------------------------------------------------------
%% @doc upgrade a single application.
%% @spec upgrade_application(Repos, TargetErtsVsn, AppName, Force, Timeout) -> ok | {error, Reason}
%%  where
%%   Repos = [string()]
%%   TargetErtsVsn = string()
%%   AppName = string()
%%   Force = force()
%% @end
%%--------------------------------------------------------------------
upgrade_application(Repos, TargetErtsVsn, AppName, Force, Timeout) -> 
    ?INFO_MSG("fax_manage:upgrade_application(~p, ~p, ~p)~n", [Repos, AppName]),
    case is_outdated_app(Repos, TargetErtsVsn, AppName, Timeout) of
	{ok, {lower, HighestLocalVsn, HighestRemoteVsn}} ->
	    io:format("Upgrading from version ~s of ~s to version ~s~n", [HighestLocalVsn, AppName, HighestRemoteVsn]),
	    fax_install:install_remote_application(Repos, TargetErtsVsn, AppName, HighestRemoteVsn, Force, Timeout); 
	{ok, {_, HighestLocalVsn}} ->
	    io:format("~s at version ~s is up to date~n", [AppName, HighestLocalVsn]);
	Error ->
	    io:format("~p~n", [Error]),
	    Error
    end.
    
%%--------------------------------------------------------------------
%% @doc 
%%  Search through and list packages in remote repositories.
%% @spec search(Repos, Side, SearchType, SearchString) -> string()
%%  where
%%   Repos = list()
%%   Side = lib | releases | both
%%   SearchType = regexp | normal
%%   SearchString = string()
%% @end
%%--------------------------------------------------------------------
search(Repos, Side, SearchType, SearchString) -> 
    FilterFun = case SearchType of
		    regexp ->
			fun(E) -> case regexp:match(E, SearchString) of {match, _, _} -> true; _ -> false end end;
		    normal ->
			fun(E) -> case regexp:match(E, ".*" ++ SearchString ++ ".*") of {match, _, _} -> true; _ -> false end end;
		    Invalid ->
			exit({"Not a valid search type, try normal or regexp", Invalid})
		end,

    case Side of
	both ->
	    Lib      = filter(FilterFun, lists:foldl(fun({_, A}, Acc) -> A ++ Acc end, [], raw_list(Repos, lib))),
	    Releases = filter(FilterFun, lists:foldl(fun({_, A}, Acc) -> A ++ Acc end, [], raw_list(Repos, releases))),
	    print_list(lib, Lib),
	    print_list(releases, Releases);
	Side ->
	    List = filter(FilterFun, lists:foldl(fun({_, A}, Acc) -> A ++ Acc end, [], raw_list(Repos, Side))),
	    print_list(Side, List)
    end.


%%====================================================================
%% Internal functions
%%====================================================================

print_list(_Side, []) ->
    ok;
print_list(lib, List) ->
    print_list2("Applications (install with: faxien install_app)", List);
print_list(releases, List) ->
    print_list2("Releases (install with: faxien install)", List).

print_list2(Header, List) ->
    io:format("~s~n", [Header]),
    lists:foreach(fun(E) -> io:format("    ~s~n", [E]) end, List).
			  


filter(FilterFun, List) -> 
    SortedList = lists:sort(List),
    element(2, lists:foldl(fun(E, {Cur, IAcc} = Acc) -> 
				   case E == Cur of
				       true  -> 
					   Acc;
				       false -> 
					   case FilterFun(E) of
					       true  -> {E, [E|IAcc]};
					       false -> Acc
					   end
				   end
			   end, {undefined, []}, SortedList)).

raw_list(Repos, Side) ->
    lists:foldl(fun(Repo, Acc) -> 
			SysInfo  = ewr_util:system_info(),
			Suffixes = ewr_util:gen_multi_erts_repo_stub_suffix("", [SysInfo, "Generic"], Side),
			try
			    lists:foldl(fun(Suf, Acc2) -> 
						?INFO_MSG("pulling data for list from ~s~n", [Repo ++ "/" ++ Suf]),
						case fax_util:repo_list(Repo ++ "/" ++ Suf) of
						    {ok, Vsns}           -> [{Repo, lists:reverse(Vsns)}|Acc2]; 
						    {error, conn_failed} -> throw(conn_failed);
						    {error, _Reason}     -> Acc2
						end
					end, Acc, Suffixes)
			catch
				conn_failed ->
				       Acc
			end
		end, [], Repos).


%%--------------------------------------------------------------------
%% @private
%% @doc Add an element to a config tuple whose value is a list.
%% @spec add_to_config_list(Key, ValueToAdd, ConfigFilePath) -> ok | {error, Reason}
%% where
%%  Reason = no_such_config_entry
%% @end
%%--------------------------------------------------------------------
add_to_config_list(Key, ValueToAdd, ConfigFilePath) ->
    gas:modify_config_value(ConfigFilePath, faxien, Key, fun(Value) -> [ValueToAdd|Value] end).

%%--------------------------------------------------------------------
%% @private
%% @doc Remove an element to a config tuple whose value is a list.
%% @spec remove_from_config_list(Key, ValueToRemove, ConfigFilePath) -> ok | {error, Reason}
%% where
%%  Reason = no_such_config_entry
%% @end
%%--------------------------------------------------------------------
remove_from_config_list(Key, ValueToRemove, ConfigFilePath) ->
    gas:modify_config_value(ConfigFilePath, faxien, Key, fun(Value) -> lists:delete(ValueToRemove, Value) end).

%%--------------------------------------------------------------------
%% @private
%% @doc A determine if a release has a lower version than what is available in the remote repositories.
%% @spec is_outdated_release(Repos, TargetErtsVsn, ReleaseName, Timeout) -> {ok, Compare} | {error, Reason}
%%  where
%%   Repos = [string()]
%%   TargetErtsVsn = string()
%%   Compare = {higher, HighestLocalVsn} | {same, HighestLocalVsn} | {lower, {HighestLocalVsn, HigherRemoteVsn}}
%% @end
%%--------------------------------------------------------------------
is_outdated_release(Repos, TargetErtsVsn, ReleaseName, _Timeout) ->
    {ok, {_Repo, HighestRemoteVsn}} = fax_util:find_highest_vsn(Repos, TargetErtsVsn, ReleaseName, releases),
    case find_highest_local_release_vsn(ReleaseName) of
	{ok, HighestLocalVsn} ->
	    case ewr_util:is_version_greater(HighestLocalVsn, HighestRemoteVsn) of
		true ->
		    {ok, {higher, HighestLocalVsn}};
		false when HighestRemoteVsn == HighestLocalVsn ->
		    {ok, {same, HighestLocalVsn}};
		false ->
		    {ok, {lower, HighestLocalVsn, HighestRemoteVsn}}
	    end;
	{error, Reason} ->
	    {error, Reason}
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc A determine if an application has a lower version than what is available in the remote repositories.
%% @spec is_outdated_app(Repos, TargetErtsVsn, AppName, Timeout) -> {ok, Compare} | {error, Reason}
%%  where
%%   Repos = [string()]
%%   TargetErtsVsn = string()
%%   Compare = {higher, HighestLocalVsn} | {same, HighestLocalVsn} | {lower, {HighestLocalVsn, HigherRemoteVsn}}
%% @end
%%--------------------------------------------------------------------
is_outdated_app(Repos, TargetErtsVsn, AppName, _Timeout) ->
    {ok, {_Repo, HighestRemoteVsn}} = fax_util:find_highest_vsn(Repos, TargetErtsVsn, AppName, lib),
    case find_highest_local_app_vsn(AppName) of
	{ok, HighestLocalVsn} ->
	    case ewr_util:is_version_greater(HighestLocalVsn, HighestRemoteVsn) of
		true ->
		    {ok, {higher, HighestLocalVsn}};
		false when HighestRemoteVsn == HighestLocalVsn ->
		    {ok, {same, HighestLocalVsn}};
		false ->
		    {ok, {lower, HighestLocalVsn, HighestRemoteVsn}}
	    end;
	{error, Reason} ->
	    {error, Reason}
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc Find the highest version of a particular release that is installed locally.
%% @spec find_highest_local_release_vsn(ReleaseName) -> {ok, HighestVsn} | {error, Reason}
%% @end
%%--------------------------------------------------------------------
find_highest_local_release_vsn(ReleaseName) ->
    highest_vsn(epkg_installed_paths:list_release_vsns(ReleaseName)).

%%--------------------------------------------------------------------
%% @private
%% @doc Find the highest version of a particular application that is installed locally.
%% @spec find_highest_local_app_vsn(AppName) -> {ok, HighestVsn} | {error, Reason}
%% @end
%%--------------------------------------------------------------------
find_highest_local_app_vsn(AppName) ->
    highest_vsn(epkg_installed_paths:list_app_vsns(AppName)).

highest_vsn(Vsns) when length(Vsns) > 0 ->
    HighestLocalVsn = hd(lists:sort(fun(A, B) -> ewr_util:is_version_greater(A, B) end, Vsns)),
    {ok, HighestLocalVsn};
highest_vsn([]) ->
    {error, app_not_installed};
highest_vsn(Error) ->
    {error, Error}.

    