#!/bin/bash

# Terminal colours.
greenColour='\e[0;32m\033[1m'
endColour='\033[0m\e[0m'
redColour='\e[0;31m\033[1m'
blueColour='\e[0;34m\033[1m'
yellowColour='\e[0;33m\033[1m'
purpleColour='\e[0;35m\033[1m'
turquoiseColour='\e[0;36m\033[1m'
grayColour='\e[0;37m\033[1m'

function ctrl_c() {
    echo -e "\n${redColour}[!] Exiting...${endColour}"
    exit 130
}

function helpPanel() {
    echo -e "\n${yellowColour}[+]${endColour}${grayColour} Usage: bash ruleta.sh -m MONEY -t STRATEGY [options]${endColour}"
    echo -e "\t${purpleColour}-m${endColour} Initial balance: integer from 1 to 1000000000."
    echo -e "\t${purpleColour}-t${endColour} Strategy: martingala, paroli or inverseLabouchere."
    echo -e "\t${purpleColour}-b${endColour} Initial bet for martingala or paroli: integer from 1 to 1000000000."
    echo -e "\t${purpleColour}-s${endColour} Betting side: par (even) or impar (odd)."
    echo -e "\t${purpleColour}-l${endColour} Disable optional profit and loss limits without prompting."
    echo -e "\t${purpleColour}-n${endColour} Maximum spins: integer from 1 to 1000000 (default: 1000)."
    echo -e "\t${purpleColour}-d${endColour} Delay between spins: 0 to 10 seconds, with up to three decimal places."
    echo -e "\t${purpleColour}-o${endColour} New CSV file for spin results; existing files are not overwritten."
    echo -e "\t${purpleColour}-r${endColour} Optional random seed: integer from 1 to 32767."
    echo -e "\t${purpleColour}-i${endColour} Session identifier: letters, digits, underscores or hyphens (default: session_001)."
    echo -e "\t${purpleColour}-h${endColour} Show this help."
    echo -e "\n${grayColour}Example: bash ruleta.sh -m 100 -t martingala -b 1 -s par -l -n 100 -d 0 -r 42 -i session_001 -o session_001.csv${endColour}"
    echo -e "${grayColour}Paroli doubles the bet after a win and resets it after a loss.${endColour}"
    echo -e "${grayColour}Optional profit and loss limits are checked after each spin and may be exceeded.${endColour}"
    echo -e "${grayColour}Seeded replay requires the same code, configuration, Bash version and compatibility settings.${endColour}"
}

function fail() {
    printf '%b\n' "${redColour}[!] $1${endColour}" >&2
    return 1
}

# Validate length before arithmetic to avoid overflow and expression evaluation.
function is_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]{0,9}$ ]] && ((10#$1 <= $2))
}

function read_value() {
    printf '%b' "${yellowColour}[+]${endColour} ${grayColour}$2${endColour}"

    if ! IFS= read -r "$1"; then
        fail 'Input was closed. The session has been cancelled.'
        return 1
    fi
}

function read_side() {
    if [[ -n "$configured_side" ]]; then
        even_odd=$configured_side
        return 0
    fi

    while true; do
        read_value even_odd 'Choose your betting side (par/impar) -> ' || return 1

        case "$even_odd" in
            par|impar) return 0 ;;
            *) fail 'Enter par or impar.' ;;
        esac
    done
}

function read_limits() {
    limits_enabled=0

    if ((skip_limits_prompt)); then
        return 0
    fi

    while true; do
        read_value answer 'Enable profit and loss limits? (y/n) -> ' || return 1

        case "$answer" in
            y|Y|s|S)
                limits_enabled=1
                break
                ;;
            n|N) return 0 ;;
            *) fail 'Enter y or n.' ;;
        esac
    done

    while true; do
        read_value benefits 'Target profit percentage (integer from 1 to 1000) -> ' || return 1
        is_positive_integer "$benefits" 1000 && break
        fail 'Enter an integer from 1 to 1000, without leading zeros.'
    done

    while true; do
        read_value losses 'Maximum loss percentage (integer from 1 to 100) -> ' || return 1
        is_positive_integer "$losses" 100 && break
        fail 'Enter an integer from 1 to 100, without leading zeros.'
    done

    # Store thresholds in hundredths of a euro to avoid rounded comparisons.
    stop_win=$((initial_money * (100 + benefits)))
    stop_loss=$((initial_money * (100 - losses)))

    printf '%b%d.%02d EUR%b\n' \
        "${yellowColour}[+]${endColour} Target profit: ${greenColour}" \
        "$((initial_money * benefits / 100))" \
        "$((initial_money * benefits % 100))" \
        "$endColour"

    printf '%b%d.%02d EUR%b\n' \
        "${yellowColour}[+]${endColour} Maximum loss: ${redColour}" \
        "$((initial_money * losses / 100))" \
        "$((initial_money * losses % 100))" \
        "$endColour"
}

function prepare_session() {
    initial_money=$money
    play_counter=0
    limits_enabled=0
    stop_reason=''

    echo -e "\n${yellowColour}[+]${endColour} Session: ${blueColour}$session_id${endColour}"
    echo -e "${yellowColour}[+]${endColour} Random seed: ${purpleColour}${random_seed:-not specified}${endColour}"
    echo -e "${yellowColour}[+]${endColour} Initial balance: ${greenColour}$money EUR${endColour}"
}

# Reject the incomplete final bucket: 32745 = 37 * 885.
# Call directly, not through command substitution, to advance RANDOM in this shell.
function spin_wheel() {
    local sample

    while true; do
        sample=$RANDOM

        if ((sample < 32745)); then
            random_number=$((sample % 37))
            return 0
        fi
    done
}

function open_csv() {
    [[ -z "$output_file" ]] && return 0

    if ! (set -o noclobber; : > "$output_file") 2>/dev/null; then
        fail 'Cannot create the CSV: the file already exists or the path is not writable.'
        return 1
    fi

    exec 3>> "$output_file" || return 1
    csv_open=1

    printf '%s\n' \
        'session_id,random_seed,strategy,spin,side,number,bet,balance_before,won,profit,balance_after' \
        >&3 || return 1
}

function can_play() {
    if ((play_counter >= max_spins)); then
        stop_reason=max_spins
        echo -e "${yellowColour}[+]${endColour} Maximum of $max_spins spins reached."
        return 1
    fi

    if ((money > 1000000000000)); then
        stop_reason=numeric_limit
        echo -e "${yellowColour}[+]${endColour} Simulator numeric safety limit reached."
        return 1
    fi

    if ((bet > money)); then
        stop_reason=insufficient_balance

        if ((money == 0)); then
            echo -e "${redColour}[!] No balance remaining.${endColour}"
        else
            echo -e "${redColour}[!] Insufficient balance for the next bet.${endColour}"
        fi

        echo -e "${yellowColour}[+]${endColour} Balance: ${greenColour}$money EUR${endColour} | Required bet: ${purpleColour}$bet EUR${endColour}"
        return 1
    fi

    return 0
}

function play_round() {
    local balance_before=$money

    money=$((money - bet))
    spin_wheel

    echo -e "\n${yellowColour}[+]${endColour} Bet: ${greenColour}$bet EUR${endColour}"
    echo -e "${yellowColour}[+]${endColour} Balance after placing the bet: ${greenColour}$money EUR${endColour}"
    echo -e "${yellowColour}[+]${endColour} Winning number: ${blueColour}$random_number${endColour}"

    won=0

    if ((random_number != 0)); then
        if [[ "$even_odd" == par ]] && ((random_number % 2 == 0)); then
            won=1
        elif [[ "$even_odd" == impar ]] && ((random_number % 2 == 1)); then
            won=1
        fi
    fi

    if ((won)); then
        reward=$((bet * 2))
        money=$((money + reward))

        echo -e "${yellowColour}[+]${endColour} ${greenColour}You win! Payout: $reward EUR; net profit: $bet EUR.${endColour}"
    else
        echo -e "${yellowColour}[+]${endColour} ${redColour}You lose $bet EUR.${endColour}"
    fi

    play_counter=$((play_counter + 1))
    echo -e "${yellowColour}[+]${endColour} Balance: ${greenColour}$money EUR${endColour}"

    if ((csv_open)); then
        if ! printf '%s,%s,%s,%d,%s,%d,%d,%d,%d,%d,%d\n' \
            "$session_id" "$random_seed" "$technique" \
            "$play_counter" "$even_odd" "$random_number" "$bet" \
            "$balance_before" "$won" "$((money - balance_before))" \
            "$money" >&3; then
            fail 'Could not save the spin to the CSV. The session has been stopped.'
            return 1
        fi
    fi
}

function limit_reached() {
    ((limits_enabled)) || return 1

    if ((money * 100 >= stop_win)); then
        stop_reason=profit_target
        echo -e "\n${yellowColour}[+]${endColour} ${greenColour}Profit target reached.${endColour}"
        return 0
    elif ((money * 100 <= stop_loss)); then
        stop_reason=loss_limit
        echo -e "\n${redColour}[!] Loss limit reached. Ending the session.${endColour}"
        return 0
    fi

    return 1
}

function show_summary() {
    echo -e "\n${yellowColour}[+]${endColour} Session: ${blueColour}$session_id${endColour}"
    echo -e "${yellowColour}[+]${endColour} Total spins: ${blueColour}$play_counter${endColour}"
    echo -e "${yellowColour}[+]${endColour} Final balance: ${greenColour}$money EUR${endColour}"
    echo -e "${yellowColour}[+]${endColour} Net profit: ${turquoiseColour}$((money - initial_money)) EUR${endColour}"
    echo -e "${yellowColour}[+]${endColour} Stop reason: ${purpleColour}$stop_reason${endColour}"

    if ((csv_open)); then
        exec 3>&-
        csv_open=0

        printf '%b%s%b\n' \
            "${yellowColour}[+]${endColour} Data saved to: ${blueColour}" \
            "$output_file" "$endColour"
    fi
}

# Shared accounting; only the next-bet rule differs between these strategies.
function run_progression() {
    local strategy=$1
    local init_bet backup_bet

    prepare_session

    if [[ -n "$base_bet" ]]; then
        init_bet=$base_bet
    else
        while true; do
            read_value init_bet 'Initial bet in whole euros -> ' || return 1

            if is_positive_integer "$init_bet" 1000000000 && ((init_bet <= money)); then
                break
            fi

            fail 'Enter a positive integer without leading zeros that does not exceed your balance.'
        done
    fi

    read_side || return 1
    read_limits || return 1

    backup_bet=$init_bet
    bet=$init_bet

    echo -e "\n${yellowColour}[+]${endColour} Initial bet: ${purpleColour}$init_bet EUR${endColour} | Side: ${purpleColour}$even_odd${endColour} | Balance: ${greenColour}$money EUR${endColour}"

    open_csv || return 1

    while can_play; do
        play_round || return 1
        limit_reached && break

        if { [[ "$strategy" == martingala ]] && ((won == 0)); } ||
           { [[ "$strategy" == paroli ]] && ((won == 1)); }; then
            bet=$((bet * 2))
            echo -e "${yellowColour}[+]${endColour} Next bet increases to: ${greenColour}$bet EUR${endColour}"
        else
            bet=$backup_bet
        fi

        sleep "$delay"
    done

    show_summary
}

function martingala() {
    run_progression martingala
}

function paroli() {
    run_progression paroli
}

function inverseLabouchere() {
    local -a my_sequence=(1 2 3 4)
    local bet_to_renew sequence_length

    prepare_session
    read_side || return 1

    echo -e "\n${yellowColour}[+]${endColour} Initial sequence: ${blueColour}[${my_sequence[*]}]${endColour}"

    bet=5
    bet_to_renew=$((money + 50))

    open_csv || return 1

    while can_play; do
        play_round || return 1

        if ((won)); then
            # Preserve the original custom renewal thresholds.
            if ((money > bet_to_renew)); then
                my_sequence=(1 2 3 4)

                echo -e "${yellowColour}[+]${endColour} Renewal threshold exceeded: ${greenColour}$bet_to_renew EUR${endColour}. Resetting sequence to ${blueColour}[${my_sequence[*]}]${endColour}"

                bet_to_renew=$((bet_to_renew + 50))
            elif ((money < bet_to_renew - 100)); then
                bet_to_renew=$((bet_to_renew - 100))
            else
                my_sequence+=("$bet")
            fi
        else
            sequence_length=${#my_sequence[@]}

            if ((sequence_length <= 2)); then
                my_sequence=()
            else
                my_sequence=("${my_sequence[@]:1:sequence_length-2}")
            fi
        fi

        echo -e "${yellowColour}[+]${endColour} Updated sequence: ${blueColour}[${my_sequence[*]}]${endColour}"

        if ((${#my_sequence[@]} == 0)); then
            my_sequence=(1 2 3 4)

            echo -e "${yellowColour}[+]${endColour} Empty sequence. Resetting to ${blueColour}[${my_sequence[*]}]${endColour}"
        fi

        sequence_length=${#my_sequence[@]}

        if ((sequence_length == 1)); then
            bet=${my_sequence[0]}
        else
            bet=$((my_sequence[0] + my_sequence[sequence_length - 1]))
        fi

        sleep "$delay"
    done

    show_summary
}

function main() {
    local arg OPTIND=1

    money=''
    technique=''
    base_bet=''
    configured_side=''
    skip_limits_prompt=0
    max_spins=1000
    delay=''
    output_file=''
    random_seed=''
    session_id='session_001'
    csv_open=0

    trap ctrl_c INT

    while getopts ':m:t:b:s:n:d:o:r:i:lh' arg; do
        case "$arg" in
            m)
                money=$OPTARG
                ;;
            t)
                technique=$OPTARG
                ;;
            b)
                base_bet=$OPTARG

                is_positive_integer "$base_bet" 1000000000 || {
                    fail 'The base bet must be an integer from 1 to 1000000000, without leading zeros.'
                    return 1
                }
                ;;
            s)
                configured_side=$OPTARG

                case "$configured_side" in
                    par|impar) ;;
                    *)
                        fail 'The betting side must be par or impar.'
                        return 1
                        ;;
                esac
                ;;
            l)
                skip_limits_prompt=1
                ;;
            n)
                max_spins=$OPTARG
                ;;
            d)
                delay=$OPTARG
                ;;
            o)
                output_file=$OPTARG

                [[ -n "$output_file" ]] || {
                    fail 'The CSV path cannot be empty.'
                    return 1
                }
                ;;
            r)
                random_seed=$OPTARG

                is_positive_integer "$random_seed" 32767 || {
                    fail 'The random seed must be an integer from 1 to 32767, without leading zeros.'
                    return 1
                }
                ;;
            i)
                session_id=$OPTARG

                if [[ ! "$session_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    fail 'The session identifier must contain only letters, digits, underscores or hyphens.'
                    return 1
                fi
                ;;
            h)
                helpPanel
                return 0
                ;;
            :)
                fail "Option -$OPTARG requires a value."
                return 1
                ;;
            \?)
                fail "Unknown option: -$OPTARG."
                helpPanel
                return 1
                ;;
        esac
    done

    shift "$((OPTIND - 1))"

    if (($#)); then
        fail 'Unexpected arguments. Use -h to display help.'
        return 1
    fi

    if ! is_positive_integer "$money" 1000000000; then
        fail 'Use -m to provide an initial balance from 1 to 1000000000, without leading zeros.'
        return 1
    fi

    case "$technique" in
        martingala|paroli)
            delay=${delay:-0.2}
            ;;
        inverseLabouchere)
            delay=${delay:-1}
            ;;
        *)
            fail 'Use -t to select martingala, paroli or inverseLabouchere.'
            return 1
            ;;
    esac

    is_positive_integer "$max_spins" 1000000 || {
        fail 'The maximum number of spins must be between 1 and 1000000.'
        return 1
    }

    [[ "$delay" =~ ^([0-9](\.[0-9]{1,3})?|10(\.0{1,3})?)$ ]] || {
        fail 'The delay must be between 0 and 10 seconds, with up to three decimal places.'
        return 1
    }

    if [[ "$technique" == inverseLabouchere && -n "$base_bet" ]]; then
        fail 'The -b option is only supported for martingala and paroli.'
        return 1
    fi

    # Seed once in the shell that runs spin_wheel.
    # Replay requires the same Bash version, compatibility settings and code.
    if [[ -n "$random_seed" ]]; then
        RANDOM=$random_seed
    fi

    "$technique"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi