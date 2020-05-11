# bash completion for ddev                                 -*- shell-script -*-

__ddev_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__ddev_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__ddev_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__ddev_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__ddev_handle_reply()
{
    __ddev_debug "${FUNCNAME[0]}"
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            COMPREPLY=( $(compgen -W "${allflags[*]}" -- "$cur") )
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __ddev_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __ddev_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions=("${must_have_one_noun[@]}")
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    COMPREPLY=( $(compgen -W "${completions[*]}" -- "$cur") )

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        COMPREPLY=( $(compgen -W "${noun_aliases[*]}" -- "$cur") )
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
		if declare -F __ddev_custom_func >/dev/null; then
			# try command name qualified custom func
			__ddev_custom_func
		else
			# otherwise fall back to unqualified for compatibility
			declare -F __custom_func >/dev/null && __custom_func
		fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__ddev_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__ddev_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1
}

__ddev_handle_flag()
{
    __ddev_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __ddev_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __ddev_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __ddev_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __ddev_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __ddev_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__ddev_handle_noun()
{
    __ddev_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __ddev_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __ddev_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__ddev_handle_command()
{
    __ddev_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_ddev_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __ddev_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__ddev_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __ddev_handle_reply
        return
    fi
    __ddev_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __ddev_handle_flag
    elif __ddev_contains_word "${words[c]}" "${commands[@]}"; then
        __ddev_handle_command
    elif [[ $c -eq 0 ]]; then
        __ddev_handle_command
    elif __ddev_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __ddev_handle_command
        else
            __ddev_handle_noun
        fi
    else
        __ddev_handle_noun
    fi
    __ddev_handle_word
}

_ddev_auth_pantheon()
{
    last_command="ddev_auth_pantheon"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_auth_ssh()
{
    last_command="ddev_auth_ssh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--ssh-key-path=")
    two_word_flags+=("--ssh-key-path")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--ssh-key-path=")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_auth()
{
    last_command="ddev_auth"

    command_aliases=()

    commands=()
    commands+=("pantheon")
    commands+=("ssh")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_composer_create()
{
    last_command="ddev_composer_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_composer_create-project()
{
    last_command="ddev_composer_create-project"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_composer()
{
    last_command="ddev_composer"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("create-project")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_config_drud-s3()
{
    last_command="ddev_config_drud-s3"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--access-key-id=")
    two_word_flags+=("--access-key-id")
    local_nonpersistent_flags+=("--access-key-id=")
    flags+=("--additional-fqdns=")
    two_word_flags+=("--additional-fqdns")
    local_nonpersistent_flags+=("--additional-fqdns=")
    flags+=("--additional-hostnames=")
    two_word_flags+=("--additional-hostnames")
    local_nonpersistent_flags+=("--additional-hostnames=")
    flags+=("--bucket-name=")
    two_word_flags+=("--bucket-name")
    local_nonpersistent_flags+=("--bucket-name=")
    flags+=("--create-docroot")
    local_nonpersistent_flags+=("--create-docroot")
    flags+=("--db-image=")
    two_word_flags+=("--db-image")
    local_nonpersistent_flags+=("--db-image=")
    flags+=("--db-image-default")
    local_nonpersistent_flags+=("--db-image-default")
    flags+=("--db-working-dir=")
    two_word_flags+=("--db-working-dir")
    local_nonpersistent_flags+=("--db-working-dir=")
    flags+=("--db-working-dir-default")
    local_nonpersistent_flags+=("--db-working-dir-default")
    flags+=("--dba-image=")
    two_word_flags+=("--dba-image")
    local_nonpersistent_flags+=("--dba-image=")
    flags+=("--dba-image-default")
    local_nonpersistent_flags+=("--dba-image-default")
    flags+=("--dba-working-dir=")
    two_word_flags+=("--dba-working-dir")
    local_nonpersistent_flags+=("--dba-working-dir=")
    flags+=("--dba-working-dir-default")
    local_nonpersistent_flags+=("--dba-working-dir-default")
    flags+=("--dbimage-extra-packages=")
    two_word_flags+=("--dbimage-extra-packages")
    local_nonpersistent_flags+=("--dbimage-extra-packages=")
    flags+=("--disable-settings-management")
    local_nonpersistent_flags+=("--disable-settings-management")
    flags+=("--docroot=")
    two_word_flags+=("--docroot")
    local_nonpersistent_flags+=("--docroot=")
    flags+=("--environment=")
    two_word_flags+=("--environment")
    local_nonpersistent_flags+=("--environment=")
    flags+=("--host-db-port=")
    two_word_flags+=("--host-db-port")
    local_nonpersistent_flags+=("--host-db-port=")
    flags+=("--host-https-port=")
    two_word_flags+=("--host-https-port")
    local_nonpersistent_flags+=("--host-https-port=")
    flags+=("--host-webserver-port=")
    two_word_flags+=("--host-webserver-port")
    local_nonpersistent_flags+=("--host-webserver-port=")
    flags+=("--http-port=")
    two_word_flags+=("--http-port")
    local_nonpersistent_flags+=("--http-port=")
    flags+=("--https-port=")
    two_word_flags+=("--https-port")
    local_nonpersistent_flags+=("--https-port=")
    flags+=("--image-defaults")
    local_nonpersistent_flags+=("--image-defaults")
    flags+=("--mailhog-port=")
    two_word_flags+=("--mailhog-port")
    local_nonpersistent_flags+=("--mailhog-port=")
    flags+=("--mariadb-version=")
    two_word_flags+=("--mariadb-version")
    local_nonpersistent_flags+=("--mariadb-version=")
    flags+=("--mysql-version=")
    two_word_flags+=("--mysql-version")
    local_nonpersistent_flags+=("--mysql-version=")
    flags+=("--nfs-mount-enabled")
    local_nonpersistent_flags+=("--nfs-mount-enabled")
    flags+=("--ngrok-args=")
    two_word_flags+=("--ngrok-args")
    local_nonpersistent_flags+=("--ngrok-args=")
    flags+=("--omit-containers=")
    two_word_flags+=("--omit-containers")
    local_nonpersistent_flags+=("--omit-containers=")
    flags+=("--php-version=")
    two_word_flags+=("--php-version")
    local_nonpersistent_flags+=("--php-version=")
    flags+=("--phpmyadmin-port=")
    two_word_flags+=("--phpmyadmin-port")
    local_nonpersistent_flags+=("--phpmyadmin-port=")
    flags+=("--project-name=")
    two_word_flags+=("--project-name")
    local_nonpersistent_flags+=("--project-name=")
    flags+=("--project-tld=")
    two_word_flags+=("--project-tld")
    local_nonpersistent_flags+=("--project-tld=")
    flags+=("--project-type=")
    two_word_flags+=("--project-type")
    local_nonpersistent_flags+=("--project-type=")
    flags+=("--secret-access-key=")
    two_word_flags+=("--secret-access-key")
    local_nonpersistent_flags+=("--secret-access-key=")
    flags+=("--show-config-location")
    local_nonpersistent_flags+=("--show-config-location")
    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--upload-dir=")
    two_word_flags+=("--upload-dir")
    local_nonpersistent_flags+=("--upload-dir=")
    flags+=("--use-dns-when-possible")
    local_nonpersistent_flags+=("--use-dns-when-possible")
    flags+=("--web-image=")
    two_word_flags+=("--web-image")
    local_nonpersistent_flags+=("--web-image=")
    flags+=("--web-image-default")
    local_nonpersistent_flags+=("--web-image-default")
    flags+=("--web-working-dir=")
    two_word_flags+=("--web-working-dir")
    local_nonpersistent_flags+=("--web-working-dir=")
    flags+=("--web-working-dir-default")
    local_nonpersistent_flags+=("--web-working-dir-default")
    flags+=("--webimage-extra-packages=")
    two_word_flags+=("--webimage-extra-packages")
    local_nonpersistent_flags+=("--webimage-extra-packages=")
    flags+=("--webserver-type=")
    two_word_flags+=("--webserver-type")
    local_nonpersistent_flags+=("--webserver-type=")
    flags+=("--working-dir-defaults")
    local_nonpersistent_flags+=("--working-dir-defaults")
    flags+=("--xdebug-enabled")
    local_nonpersistent_flags+=("--xdebug-enabled")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_config_global()
{
    last_command="ddev_config_global"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--instrumentation-opt-in")
    local_nonpersistent_flags+=("--instrumentation-opt-in")
    flags+=("--omit-containers=")
    two_word_flags+=("--omit-containers")
    local_nonpersistent_flags+=("--omit-containers=")
    flags+=("--router-bind-all-interfaces")
    local_nonpersistent_flags+=("--router-bind-all-interfaces")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_config_pantheon()
{
    last_command="ddev_config_pantheon"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--additional-fqdns=")
    two_word_flags+=("--additional-fqdns")
    local_nonpersistent_flags+=("--additional-fqdns=")
    flags+=("--additional-hostnames=")
    two_word_flags+=("--additional-hostnames")
    local_nonpersistent_flags+=("--additional-hostnames=")
    flags+=("--create-docroot")
    local_nonpersistent_flags+=("--create-docroot")
    flags+=("--db-image=")
    two_word_flags+=("--db-image")
    local_nonpersistent_flags+=("--db-image=")
    flags+=("--db-image-default")
    local_nonpersistent_flags+=("--db-image-default")
    flags+=("--db-working-dir=")
    two_word_flags+=("--db-working-dir")
    local_nonpersistent_flags+=("--db-working-dir=")
    flags+=("--db-working-dir-default")
    local_nonpersistent_flags+=("--db-working-dir-default")
    flags+=("--dba-image=")
    two_word_flags+=("--dba-image")
    local_nonpersistent_flags+=("--dba-image=")
    flags+=("--dba-image-default")
    local_nonpersistent_flags+=("--dba-image-default")
    flags+=("--dba-working-dir=")
    two_word_flags+=("--dba-working-dir")
    local_nonpersistent_flags+=("--dba-working-dir=")
    flags+=("--dba-working-dir-default")
    local_nonpersistent_flags+=("--dba-working-dir-default")
    flags+=("--dbimage-extra-packages=")
    two_word_flags+=("--dbimage-extra-packages")
    local_nonpersistent_flags+=("--dbimage-extra-packages=")
    flags+=("--disable-settings-management")
    local_nonpersistent_flags+=("--disable-settings-management")
    flags+=("--docroot=")
    two_word_flags+=("--docroot")
    local_nonpersistent_flags+=("--docroot=")
    flags+=("--host-db-port=")
    two_word_flags+=("--host-db-port")
    local_nonpersistent_flags+=("--host-db-port=")
    flags+=("--host-https-port=")
    two_word_flags+=("--host-https-port")
    local_nonpersistent_flags+=("--host-https-port=")
    flags+=("--host-webserver-port=")
    two_word_flags+=("--host-webserver-port")
    local_nonpersistent_flags+=("--host-webserver-port=")
    flags+=("--http-port=")
    two_word_flags+=("--http-port")
    local_nonpersistent_flags+=("--http-port=")
    flags+=("--https-port=")
    two_word_flags+=("--https-port")
    local_nonpersistent_flags+=("--https-port=")
    flags+=("--image-defaults")
    local_nonpersistent_flags+=("--image-defaults")
    flags+=("--mailhog-port=")
    two_word_flags+=("--mailhog-port")
    local_nonpersistent_flags+=("--mailhog-port=")
    flags+=("--mariadb-version=")
    two_word_flags+=("--mariadb-version")
    local_nonpersistent_flags+=("--mariadb-version=")
    flags+=("--mysql-version=")
    two_word_flags+=("--mysql-version")
    local_nonpersistent_flags+=("--mysql-version=")
    flags+=("--nfs-mount-enabled")
    local_nonpersistent_flags+=("--nfs-mount-enabled")
    flags+=("--ngrok-args=")
    two_word_flags+=("--ngrok-args")
    local_nonpersistent_flags+=("--ngrok-args=")
    flags+=("--omit-containers=")
    two_word_flags+=("--omit-containers")
    local_nonpersistent_flags+=("--omit-containers=")
    flags+=("--pantheon-environment=")
    two_word_flags+=("--pantheon-environment")
    local_nonpersistent_flags+=("--pantheon-environment=")
    flags+=("--php-version=")
    two_word_flags+=("--php-version")
    local_nonpersistent_flags+=("--php-version=")
    flags+=("--phpmyadmin-port=")
    two_word_flags+=("--phpmyadmin-port")
    local_nonpersistent_flags+=("--phpmyadmin-port=")
    flags+=("--project-name=")
    two_word_flags+=("--project-name")
    local_nonpersistent_flags+=("--project-name=")
    flags+=("--project-tld=")
    two_word_flags+=("--project-tld")
    local_nonpersistent_flags+=("--project-tld=")
    flags+=("--project-type=")
    two_word_flags+=("--project-type")
    local_nonpersistent_flags+=("--project-type=")
    flags+=("--show-config-location")
    local_nonpersistent_flags+=("--show-config-location")
    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--upload-dir=")
    two_word_flags+=("--upload-dir")
    local_nonpersistent_flags+=("--upload-dir=")
    flags+=("--use-dns-when-possible")
    local_nonpersistent_flags+=("--use-dns-when-possible")
    flags+=("--web-image=")
    two_word_flags+=("--web-image")
    local_nonpersistent_flags+=("--web-image=")
    flags+=("--web-image-default")
    local_nonpersistent_flags+=("--web-image-default")
    flags+=("--web-working-dir=")
    two_word_flags+=("--web-working-dir")
    local_nonpersistent_flags+=("--web-working-dir=")
    flags+=("--web-working-dir-default")
    local_nonpersistent_flags+=("--web-working-dir-default")
    flags+=("--webimage-extra-packages=")
    two_word_flags+=("--webimage-extra-packages")
    local_nonpersistent_flags+=("--webimage-extra-packages=")
    flags+=("--webserver-type=")
    two_word_flags+=("--webserver-type")
    local_nonpersistent_flags+=("--webserver-type=")
    flags+=("--working-dir-defaults")
    local_nonpersistent_flags+=("--working-dir-defaults")
    flags+=("--xdebug-enabled")
    local_nonpersistent_flags+=("--xdebug-enabled")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_config()
{
    last_command="ddev_config"

    command_aliases=()

    commands=()
    commands+=("drud-s3")
    commands+=("global")
    commands+=("pantheon")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--additional-fqdns=")
    two_word_flags+=("--additional-fqdns")
    local_nonpersistent_flags+=("--additional-fqdns=")
    flags+=("--additional-hostnames=")
    two_word_flags+=("--additional-hostnames")
    local_nonpersistent_flags+=("--additional-hostnames=")
    flags+=("--create-docroot")
    local_nonpersistent_flags+=("--create-docroot")
    flags+=("--db-image=")
    two_word_flags+=("--db-image")
    local_nonpersistent_flags+=("--db-image=")
    flags+=("--db-image-default")
    local_nonpersistent_flags+=("--db-image-default")
    flags+=("--db-working-dir=")
    two_word_flags+=("--db-working-dir")
    local_nonpersistent_flags+=("--db-working-dir=")
    flags+=("--db-working-dir-default")
    local_nonpersistent_flags+=("--db-working-dir-default")
    flags+=("--dba-image=")
    two_word_flags+=("--dba-image")
    local_nonpersistent_flags+=("--dba-image=")
    flags+=("--dba-image-default")
    local_nonpersistent_flags+=("--dba-image-default")
    flags+=("--dba-working-dir=")
    two_word_flags+=("--dba-working-dir")
    local_nonpersistent_flags+=("--dba-working-dir=")
    flags+=("--dba-working-dir-default")
    local_nonpersistent_flags+=("--dba-working-dir-default")
    flags+=("--dbimage-extra-packages=")
    two_word_flags+=("--dbimage-extra-packages")
    local_nonpersistent_flags+=("--dbimage-extra-packages=")
    flags+=("--disable-settings-management")
    local_nonpersistent_flags+=("--disable-settings-management")
    flags+=("--docroot=")
    two_word_flags+=("--docroot")
    local_nonpersistent_flags+=("--docroot=")
    flags+=("--host-db-port=")
    two_word_flags+=("--host-db-port")
    local_nonpersistent_flags+=("--host-db-port=")
    flags+=("--host-https-port=")
    two_word_flags+=("--host-https-port")
    local_nonpersistent_flags+=("--host-https-port=")
    flags+=("--host-webserver-port=")
    two_word_flags+=("--host-webserver-port")
    local_nonpersistent_flags+=("--host-webserver-port=")
    flags+=("--http-port=")
    two_word_flags+=("--http-port")
    local_nonpersistent_flags+=("--http-port=")
    flags+=("--https-port=")
    two_word_flags+=("--https-port")
    local_nonpersistent_flags+=("--https-port=")
    flags+=("--image-defaults")
    local_nonpersistent_flags+=("--image-defaults")
    flags+=("--mailhog-port=")
    two_word_flags+=("--mailhog-port")
    local_nonpersistent_flags+=("--mailhog-port=")
    flags+=("--mariadb-version=")
    two_word_flags+=("--mariadb-version")
    local_nonpersistent_flags+=("--mariadb-version=")
    flags+=("--mysql-version=")
    two_word_flags+=("--mysql-version")
    local_nonpersistent_flags+=("--mysql-version=")
    flags+=("--nfs-mount-enabled")
    local_nonpersistent_flags+=("--nfs-mount-enabled")
    flags+=("--ngrok-args=")
    two_word_flags+=("--ngrok-args")
    local_nonpersistent_flags+=("--ngrok-args=")
    flags+=("--omit-containers=")
    two_word_flags+=("--omit-containers")
    local_nonpersistent_flags+=("--omit-containers=")
    flags+=("--php-version=")
    two_word_flags+=("--php-version")
    local_nonpersistent_flags+=("--php-version=")
    flags+=("--phpmyadmin-port=")
    two_word_flags+=("--phpmyadmin-port")
    local_nonpersistent_flags+=("--phpmyadmin-port=")
    flags+=("--project-name=")
    two_word_flags+=("--project-name")
    local_nonpersistent_flags+=("--project-name=")
    flags+=("--project-tld=")
    two_word_flags+=("--project-tld")
    local_nonpersistent_flags+=("--project-tld=")
    flags+=("--project-type=")
    two_word_flags+=("--project-type")
    local_nonpersistent_flags+=("--project-type=")
    flags+=("--show-config-location")
    local_nonpersistent_flags+=("--show-config-location")
    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--upload-dir=")
    two_word_flags+=("--upload-dir")
    local_nonpersistent_flags+=("--upload-dir=")
    flags+=("--use-dns-when-possible")
    local_nonpersistent_flags+=("--use-dns-when-possible")
    flags+=("--web-image=")
    two_word_flags+=("--web-image")
    local_nonpersistent_flags+=("--web-image=")
    flags+=("--web-image-default")
    local_nonpersistent_flags+=("--web-image-default")
    flags+=("--web-working-dir=")
    two_word_flags+=("--web-working-dir")
    local_nonpersistent_flags+=("--web-working-dir=")
    flags+=("--web-working-dir-default")
    local_nonpersistent_flags+=("--web-working-dir-default")
    flags+=("--webimage-extra-packages=")
    two_word_flags+=("--webimage-extra-packages")
    local_nonpersistent_flags+=("--webimage-extra-packages=")
    flags+=("--webserver-type=")
    two_word_flags+=("--webserver-type")
    local_nonpersistent_flags+=("--webserver-type=")
    flags+=("--working-dir-defaults")
    local_nonpersistent_flags+=("--working-dir-defaults")
    flags+=("--xdebug-enabled")
    local_nonpersistent_flags+=("--xdebug-enabled")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_debug_compose-config()
{
    last_command="ddev_debug_compose-config"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_debug_configyaml()
{
    last_command="ddev_debug_configyaml"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_debug_nfsmount()
{
    last_command="ddev_debug_nfsmount"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_debug()
{
    last_command="ddev_debug"

    command_aliases=()

    commands=()
    commands+=("compose-config")
    commands+=("configyaml")
    commands+=("nfsmount")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_delete_images()
{
    last_command="ddev_delete_images"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_delete()
{
    last_command="ddev_delete"

    command_aliases=()

    commands=()
    commands+=("images")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--clean-containers")
    local_nonpersistent_flags+=("--clean-containers")
    flags+=("--omit-snapshot")
    flags+=("-O")
    local_nonpersistent_flags+=("--omit-snapshot")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_describe()
{
    last_command="ddev_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_exec()
{
    last_command="ddev_exec"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dir=")
    two_word_flags+=("--dir")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--dir=")
    flags+=("--service=")
    two_word_flags+=("--service")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--service=")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_export-db()
{
    last_command="ddev_export-db"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--file=")
    two_word_flags+=("--file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--file=")
    flags+=("--gzip")
    flags+=("-z")
    local_nonpersistent_flags+=("--gzip")
    flags+=("--target-db=")
    two_word_flags+=("--target-db")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--target-db=")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_hostname()
{
    last_command="ddev_hostname"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--remove")
    flags+=("-r")
    local_nonpersistent_flags+=("--remove")
    flags+=("--remove-inactive")
    flags+=("-R")
    local_nonpersistent_flags+=("--remove-inactive")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_import-db()
{
    last_command="ddev_import-db"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--extract-path=")
    two_word_flags+=("--extract-path")
    local_nonpersistent_flags+=("--extract-path=")
    flags+=("--no-drop")
    local_nonpersistent_flags+=("--no-drop")
    flags+=("--progress")
    flags+=("-p")
    local_nonpersistent_flags+=("--progress")
    flags+=("--src=")
    two_word_flags+=("--src")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--src=")
    flags+=("--target-db=")
    two_word_flags+=("--target-db")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--target-db=")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_import-files()
{
    last_command="ddev_import-files"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--extract-path=")
    two_word_flags+=("--extract-path")
    local_nonpersistent_flags+=("--extract-path=")
    flags+=("--src=")
    two_word_flags+=("--src")
    local_nonpersistent_flags+=("--src=")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_list()
{
    last_command="ddev_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--active-only")
    flags+=("-A")
    local_nonpersistent_flags+=("--active-only")
    flags+=("--continuous")
    local_nonpersistent_flags+=("--continuous")
    flags+=("--continuous-sleep-interval=")
    two_word_flags+=("--continuous-sleep-interval")
    two_word_flags+=("-I")
    local_nonpersistent_flags+=("--continuous-sleep-interval=")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_logs()
{
    last_command="ddev_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--follow")
    flags+=("-f")
    local_nonpersistent_flags+=("--follow")
    flags+=("--service=")
    two_word_flags+=("--service")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--service=")
    flags+=("--tail=")
    two_word_flags+=("--tail")
    local_nonpersistent_flags+=("--tail=")
    flags+=("--time")
    flags+=("-t")
    local_nonpersistent_flags+=("--time")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_pause()
{
    last_command="ddev_pause"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_poweroff()
{
    last_command="ddev_poweroff"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_pull()
{
    last_command="ddev_pull"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--env=")
    two_word_flags+=("--env")
    local_nonpersistent_flags+=("--env=")
    flags+=("--skip-confirmation")
    flags+=("-y")
    local_nonpersistent_flags+=("--skip-confirmation")
    flags+=("--skip-db")
    local_nonpersistent_flags+=("--skip-db")
    flags+=("--skip-files")
    local_nonpersistent_flags+=("--skip-files")
    flags+=("--skip-import")
    local_nonpersistent_flags+=("--skip-import")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_restart()
{
    last_command="ddev_restart"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_restore-snapshot()
{
    last_command="ddev_restore-snapshot"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_sequelpro()
{
    last_command="ddev_sequelpro"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_share()
{
    last_command="ddev_share"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--subdomain=")
    two_word_flags+=("--subdomain")
    local_nonpersistent_flags+=("--subdomain=")
    flags+=("--use-http")
    local_nonpersistent_flags+=("--use-http")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_snapshot()
{
    last_command="ddev_snapshot"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_ssh()
{
    last_command="ddev_ssh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dir=")
    two_word_flags+=("--dir")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--dir=")
    flags+=("--service=")
    two_word_flags+=("--service")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--service=")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_start()
{
    last_command="ddev_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_stop()
{
    last_command="ddev_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--omit-snapshot")
    flags+=("-O")
    local_nonpersistent_flags+=("--omit-snapshot")
    flags+=("--remove-data")
    flags+=("-R")
    local_nonpersistent_flags+=("--remove-data")
    flags+=("--snapshot")
    flags+=("-S")
    local_nonpersistent_flags+=("--snapshot")
    flags+=("--stop-ssh-agent")
    local_nonpersistent_flags+=("--stop-ssh-agent")
    flags+=("--unlist")
    flags+=("-U")
    local_nonpersistent_flags+=("--unlist")
    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_version()
{
    last_command="ddev_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_ddev_root_command()
{
    last_command="ddev"

    command_aliases=()

    commands=()
    commands+=("auth")
    commands+=("composer")
    commands+=("config")
    commands+=("debug")
    commands+=("delete")
    commands+=("describe")
    commands+=("exec")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=(".")
        aliashash["."]="exec"
    fi
    commands+=("export-db")
    commands+=("hostname")
    commands+=("import-db")
    commands+=("import-files")
    commands+=("list")
    commands+=("logs")
    commands+=("pause")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("sc")
        aliashash["sc"]="pause"
        command_aliases+=("stop-containers")
        aliashash["stop-containers"]="pause"
    fi
    commands+=("poweroff")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("powerdown")
        aliashash["powerdown"]="poweroff"
    fi
    commands+=("pull")
    commands+=("restart")
    commands+=("restore-snapshot")
    commands+=("sequelpro")
    commands+=("share")
    commands+=("snapshot")
    commands+=("ssh")
    commands+=("start")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="start"
    fi
    commands+=("stop")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("remove")
        aliashash["remove"]="stop"
        command_aliases+=("rm")
        aliashash["rm"]="stop"
    fi
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json-output")
    flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_ddev()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __ddev_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("ddev")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local last_command
    local nouns=()

    __ddev_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_ddev ddev
else
    complete -o default -o nospace -F __start_ddev ddev
fi

# ex: ts=4 sw=4 et filetype=sh
