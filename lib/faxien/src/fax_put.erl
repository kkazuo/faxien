%%%-------------------------------------------------------------------
%%% @author Martin Logan 
%%% @doc The functions in this file place packages and artifacts into a remote repository. 
%%% 
%%% @copyright (C) 2007, Martin Logan, Eric Merritt, Erlware
%%% @end
%%%-------------------------------------------------------------------
-module(fax_put).

-export([
	 put_erts_package/4,
	 put_binary_app_package/6,
	 put_generic_app_package/6,
	 put_release_package/6,
	 put_dot_app_file/6
	]).

%%====================================================================
%% API
%%====================================================================

%%--------------------------------------------------------------------
%% @doc put an erts archive onto a remote repository.
%% @spec put_erts_package(Repos, ErtsVsn, Payload, Timeout) -> {ok, Urls} | {error, Reason}
%% where
%%  Timeout = Milliseonds::integer()
%% @end 
%%--------------------------------------------------------------------
put_erts_package(Repos, ErtsVsn, Payload, Timeout) when is_binary(Payload) -> 
    SysInfo = ewr_util:system_info(),
    Suffix  = ewr_repo_paths:erts_package_suffix(ErtsVsn, SysInfo),
    repos_put(Repos, Suffix, Payload, Timeout).
    
%%--------------------------------------------------------------------
%% @doc put a binary application package onto a remote repository.
%% @spec put_binary_app_package(Repos, ErtsVsn, AppName, AppVsn, Payload, Timeout) -> {ok, Urls} | {error, Reason}
%% where
%%  Timeout = Milliseonds::integer()
%% @end 
%%--------------------------------------------------------------------
put_binary_app_package(Repos, ErtsVsn, AppName, AppVsn, Payload, Timeout) when is_binary(Payload) -> 
    SysInfo = ewr_util:system_info(),
    Suffix  = ewr_repo_paths:package_suffix(ErtsVsn, SysInfo, "lib", AppName, AppVsn),
    repos_put(Repos, Suffix, Payload, Timeout).

%%--------------------------------------------------------------------
%% @doc put a genric, i.e platform independent, application package onto a remote repository.
%% @spec put_generic_app_package(Repos, ErtsVsn, AppName, AppVsn, Payload, Timeout) -> {ok, Urls} | {error, Reason}
%% where
%%  Timeout = Milliseonds::integer()
%% @end 
%%--------------------------------------------------------------------
put_generic_app_package(Repos, ErtsVsn, AppName, AppVsn, Payload, Timeout) when is_binary(Payload) -> 
    Suffix = ewr_repo_paths:package_suffix(ErtsVsn, "Generic", "lib", AppName, AppVsn),
    repos_put(Repos, Suffix, Payload, Timeout).

%%--------------------------------------------------------------------
%% @doc put a release package onto a remote repository.
%% @spec put_release_package(Repos, ErtsVsn, RelName, RelVsn, Payload, Timeout) -> {ok, Urls} | {error, Reason}
%% where
%%  Timeout = Milliseonds::integer()
%% @end 
%%--------------------------------------------------------------------
put_release_package(Repos, ErtsVsn, RelName, RelVsn, Payload, Timeout) when is_binary(Payload) -> 
    Suffix = ewr_repo_paths:package_suffix(ErtsVsn, "Generic", "releases", RelName, RelVsn),
    repos_put(Repos, Suffix, Payload, Timeout).
    
%%--------------------------------------------------------------------
%% @doc put a .app onto a remote repository.
%% @spec put_dot_app_file(Repos, ErtsVsn, AppName, AppVsn, Payload, Timeout) -> {ok, Urls} | {error, Reason}
%% where
%%  Timeout = Milliseonds::integer()
%% @end 
%%--------------------------------------------------------------------
put_dot_app_file(Repos, ErtsVsn, AppName, AppVsn, Payload, Timeout) when is_binary(Payload) -> 
    Suffix = ewr_repo_paths:dot_app_file_suffix(ErtsVsn, AppName, AppVsn),
    repos_put(Repos, Suffix, Payload, Timeout).

%%====================================================================
%% Internal functions
%%====================================================================

%%-------------------------------------------------------------------
%% @private
%% @doc
%%  Put bits onto multiple filesystems.  This function creates the directory strcuture speficied if it does not exist.
%% <pre>
%% Example:
%%  repos_put(["http://www.erlware.org/stable"], "home/jdoe/my_proj/lib/my_app/my_app.tar.gz", MyAppTarBinary, 100000).
%%
%% Variables: 
%%  AppDir - a full path to the directory of the app to be put.
%%  URL - The url that the payload was PUT to.
%% </pre>
%% @spec repos_put(Repos::list(), Suffix::string(), Payload::binary(), Timeout) -> {ok, URLS} | {error, ErrorReport}
%% where
%%  Timeout = Milliseonds::integer()
%% @end
%%-------------------------------------------------------------------
repos_put(Repos, Suffix, Payload, Timeout) ->
    payloads_put(Repos, fun(Repo) -> ewr_repo_dav:repo_put(Repo, Suffix, Payload, Timeout) end).
				 

%%-------------------------------------------------------------------
%% @private
%% @doc
%%  Put bits onto multiple filesystems.  This function creates the directory strcuture speficied if it does not exist.
%% <pre>
%% Example:
%%  payloads_put(["http://www.erlware.org/stable"], fun(Repo) -> ewr_repo_dav:repo_put(Repo, Suffix, Payload, Timeout) end).
%%
%% Variables: 
%%  AppDir - a full path to the directory of the app to be put.
%%  URL - The url that the payload was PUT to.
%% </pre>
%% @spec payloads_put(Repos::list(), PayloadFun::fun()) -> {ok, URLS} | {error, ErrorReport}
%% @end
%%-------------------------------------------------------------------
payloads_put(Repos, PayloadFun) ->
     Res = 
	lists:foldl(fun(Repo, {Good, Bad}) -> 
			    case catch PayloadFun(Repo) of
				{ok, Url} -> {[Url|Good], Bad};
				Error     -> {Good, [{Repo, Error}|Bad]}
			    end 
		    end,
		    {[], []}, Repos),
    case Res of
	{Success, []}      -> {ok, Success};
	{[], Failure}      -> {error, {publish_failure, Failure}};
	{Success, Failure} -> {error, {publish_partial_failure, {publish_success, Success}, {publish_failure, Failure}}}
    end.
			   