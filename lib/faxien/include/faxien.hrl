%% Contains shared macros


-import (error_logger).


-define (CURRENT_FUNCTION, tuple_to_list (hd (tl (tuple_to_list (process_info (self (), current_function)))))).

%% Usage: ?INFO_MSG("info message ~p~n", [Reason]),
%% INFO_MSG(Msg, Args) -> ok

-define (INFO_MSG (Msg, Args), error_logger:info_msg ("~p:~p/~p (line ~p) " ++ Msg, ?CURRENT_FUNCTION ++ [?LINE | Args])).


%% Usage: ?ERROR_MSG("error message ~p~n", [Reason]),
%% ERROR_MSG(Msg, Args) -> ok

-define (ERROR_MSG (Msg, Args), error_logger:error_msg ("~p:~p/~p (line ~p) " ++ Msg, ?CURRENT_FUNCTION ++ [?LINE | Args])).

%% Default faxien installtion path otherwise known as the prefix. 
-define(INSTALLATION_PATH, "/usr/local/erlware").

-define(PACKAGE_NAME_REGEXP, "[a-z]+[a-zA-Z0-9_]*").
-define(PACKAGE_VSN_REGEXP, "[a-zA-Z0-9_]+([.-][a-zA-Z0-9_]+)*").
-define(PACKAGE_NAME_AND_VSN_REGEXP, lists:flatten(["^", ?PACKAGE_NAME_REGEXP, "-", ?PACKAGE_VSN_REGEXP, "(\.tar\.gz)*$"])).

