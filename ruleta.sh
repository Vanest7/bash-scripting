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
    echo -e "\n${redColour}[!] Saliendo...${endColour}"
    exit 130
}

function helpPanel() {
    echo -e "\n${yellowColour}[+]${endColour}${grayColour} Uso: bash ruleta.sh -m DINERO -t TECNICA [opciones]${endColour}"
    echo -e "\t${purpleColour}-m${endColour} Dinero inicial: euros enteros de 1 a 1000000000."
    echo -e "\t${purpleColour}-t${endColour} Técnica: martingala, paroli o inverseLabouchere."
    echo -e "\t${purpleColour}-n${endColour} Máximo de tiradas (1 a 1000000; por defecto, 1000)."
    echo -e "\t${purpleColour}-d${endColour} Pausa entre tiradas, en segundos (0 a 10; admite punto decimal)."
    echo -e "\t${purpleColour}-o${endColour} Archivo CSV nuevo donde guardar las tiradas; no sobrescribe archivos."
    echo -e "\t${purpleColour}-h${endColour} Mostrar esta ayuda."
    echo -e "\n${grayColour}Ejemplo: bash ruleta.sh -m 100 -t martingala -n 100 -d 0 -o results.csv${endColour}"
    echo -e "${grayColour}Paroli conserva tu variante: duplica tras ganar y reinicia tras perder.${endColour}"
    echo -e "${grayColour}Los límites se comprueban después de resolver cada tirada y pueden sobrepasarse.${endColour}"
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
        fail 'Se ha cerrado la entrada. La partida se cancela.'
        return 1
    fi
}

function read_side() {
    while true; do
        read_value even_odd '¿A qué deseas apostar continuamente (par/impar)? -> ' || return 1
        case "$even_odd" in
            par|impar) return 0 ;;
            *) fail 'Escribe par o impar.' ;;
        esac
    done
}

function read_limits() {
    limits_enabled=0
    while true; do
        read_value answer '¿Deseas poner límites? s/n -> ' || return 1
        case "$answer" in
            s|S) limits_enabled=1; break ;;
            n|N) return 0 ;;
            *) fail 'Escribe s o n.' ;;
        esac
    done
    while true; do
        read_value benefits '¿Qué porcentaje deseas ganar? (entero de 1 a 1000) -> ' || return 1
        is_positive_integer "$benefits" 1000 && break
        fail 'Introduce un porcentaje entero de 1 a 1000, sin ceros iniciales.'
    done
    while true; do
        read_value losses '¿Qué porcentaje estás dispuesto/a a perder? (entero de 1 a 100) -> ' || return 1
        is_positive_integer "$losses" 100 && break
        fail 'Introduce un porcentaje entero de 1 a 100, sin ceros iniciales.'
    done
    # Store thresholds in hundredths of a euro to avoid rounded comparisons.
    stop_win=$((initial_money * (100 + benefits)))
    stop_loss=$((initial_money * (100 - losses)))
    printf '%b%d,%02d €%b\n' "${yellowColour}[+]${endColour} Dinero que deseas ganar: ${greenColour}" \
        "$((initial_money * benefits / 100))" "$((initial_money * benefits % 100))" "$endColour"
    printf '%b%d,%02d €%b\n' "${yellowColour}[+]${endColour} Dinero que estás dispuesto/a a perder: ${redColour}" \
        "$((initial_money * losses / 100))" "$((initial_money * losses % 100))" "$endColour"
}

function prepare_session() {
    initial_money=$money
    play_counter=0
    limits_enabled=0
    stop_reason=''
    echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Dinero actual:${endColour} ${greenColour}$money€${endColour}"
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
        fail 'No se puede crear el CSV: ya existe o la ruta no permite escribir.'
        return 1
    fi
    exec 3>> "$output_file" || return 1
    csv_open=1
    printf '%s\n' 'strategy,spin,side,number,bet,balance_before,won,profit,balance_after' >&3 || return 1
}

function can_play() {
    if ((play_counter >= max_spins)); then
        stop_reason=max_spins
        echo -e "${yellowColour}[+]${endColour} Se ha alcanzado el máximo de $max_spins tiradas."
        return 1
    fi
    if ((money > 1000000000000)); then
        stop_reason=numeric_limit
        echo -e "${yellowColour}[+]${endColour} Se ha alcanzado el límite numérico de seguridad del simulador."
        return 1
    fi
    if ((bet > money)); then
        stop_reason=insufficient_balance
        if ((money == 0)); then
            echo -e "${redColour}[!] Te has quedado sin pasta. ¡Adiós!${endColour}"
        else
            echo -e "${redColour}[!] No tienes saldo suficiente para la siguiente apuesta.${endColour}"
        fi
        echo -e "${yellowColour}[+]${endColour} Saldo: ${greenColour}$money€${endColour} | Apuesta necesaria: ${purpleColour}$bet€${endColour}"
        return 1
    fi
    return 0
}

function play_round() {
    local balance_before=$money
    money=$((money - bet))
    spin_wheel
    echo -e "\n${yellowColour}[+]${endColour}${grayColour} Apostamos ${endColour}${greenColour}$bet€${endColour}"
    echo -e "${yellowColour}[+]${endColour}${grayColour} Saldo tras colocar la apuesta: ${endColour}${greenColour}$money€${endColour}"
    echo -e "${yellowColour}[+]${endColour} ${grayColour}Ha salido el número${endColour} ${blueColour}$random_number${endColour}"
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
        echo -e "${yellowColour}[+]${endColour} ${greenColour}¡Ganas! Recibes $reward€; beneficio neto de esta tirada: $bet€.${endColour}"
    else
        echo -e "${yellowColour}[+]${endColour} ${redColour}Pierdes $bet€.${endColour}"
    fi
    play_counter=$((play_counter + 1))
    echo -e "${yellowColour}[+]${endColour} Saldo: ${greenColour}$money€${endColour}"
    if ((csv_open)); then
        if ! printf '%s,%d,%s,%d,%d,%d,%d,%d,%d\n' \
            "$technique" "$play_counter" "$even_odd" "$random_number" "$bet" \
            "$balance_before" "$won" "$((money - balance_before))" "$money" >&3; then
            fail 'No se ha podido guardar la tirada en el CSV. Se detiene la partida.'
            return 1
        fi
    fi
}

function limit_reached() {
    ((limits_enabled)) || return 1
    if ((money * 100 >= stop_win)); then
        stop_reason=profit_target
        echo -e "\n${yellowColour}[+]${endColour} ${greenColour}¡¡Enhorabuena!! Has llegado a las ganancias deseadas.${endColour}"
        return 0
    elif ((money * 100 <= stop_loss)); then
        stop_reason=loss_limit
        echo -e "\n${redColour}[!] Has alcanzado tu límite de pérdidas. Finalizamos la partida.${endColour}"
        return 0
    fi
    return 1
}

function show_summary() {
    echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Jugadas totales: ${endColour}${blueColour}$play_counter${endColour}"
    echo -e "${yellowColour}[+]${endColour} Saldo final: ${greenColour}$money€${endColour}"
    echo -e "${yellowColour}[+]${endColour} Resultado neto: ${turquoiseColour}$((money - initial_money))€${endColour}"
    if ((csv_open)); then
        exec 3>&-
        csv_open=0
        printf '%b%s%b\n' "${yellowColour}[+]${endColour} Datos guardados en: ${blueColour}" "$output_file" "$endColour"
    fi
}

# Shared accounting; only the next-bet rule differs between these strategies.
function run_progression() {
    local strategy=$1
    local init_bet backup_bet
    prepare_session
    while true; do
        read_value init_bet '¿Cuánto dinero quieres apostar? (euros enteros) -> ' || return 1
        if is_positive_integer "$init_bet" 1000000000 && ((init_bet <= money)); then
            break
        fi
        fail 'Introduce una apuesta entera positiva, sin ceros iniciales y que no supere tu saldo.'
    done
    read_side || return 1
    read_limits || return 1
    backup_bet=$init_bet
    bet=$init_bet
    echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Vamos a jugar con una cantidad inicial de ${endColour}${purpleColour}$init_bet€${endColour} ${grayColour}a${endColour} ${purpleColour}$even_odd${endColour}${grayColour}. Saldo actual: ${endColour}${greenColour}$money€${endColour}"
    open_csv || return 1
    while can_play; do
        play_round || return 1
        limit_reached && break
        if { [[ "$strategy" == martingala ]] && ((won == 0)); } ||
           { [[ "$strategy" == paroli ]] && ((won == 1)); }; then
            bet=$((bet * 2))
            echo -e "${yellowColour}[+]${endColour} ${grayColour}La apuesta sube a: ${endColour}${greenColour}$bet€${endColour}"
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
    echo -e "\n${yellowColour}[+]${endColour}${grayColour}Comenzamos con la secuencia ${endColour}${blueColour}[${my_sequence[*]}]${endColour}"
    bet=5
    bet_to_renew=$((money + 50))
    open_csv || return 1
    while can_play; do
        play_round || return 1
        if ((won)); then
            # Preserve the original custom renewal thresholds.
            if ((money > bet_to_renew)); then
                my_sequence=(1 2 3 4)
                echo -e "${yellowColour}[+]${endColour}${grayColour} Se ha superado el límite de ganancias establecido en ${endColour}${greenColour}$bet_to_renew€${endColour}${grayColour}, restableciendo la secuencia a ${endColour}${blueColour}[${my_sequence[*]}]${endColour}"
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
        echo -e "${yellowColour}[+]${endColour} ${grayColour}La nueva secuencia es: ${endColour}${blueColour}[${my_sequence[*]}]${endColour}"
        if ((${#my_sequence[@]} == 0)); then
            my_sequence=(1 2 3 4)
            echo -e "${redColour}[!] Hemos perdido nuestra secuencia.${endColour}"
            echo -e "${yellowColour}[+]${endColour}${grayColour} Restableciendo la secuencia a: ${endColour}${blueColour}[${my_sequence[*]}]${endColour}"
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
    max_spins=1000
    delay=''
    output_file=''
    csv_open=0
    trap ctrl_c INT
    while getopts ':m:t:n:d:o:h' arg; do
        case "$arg" in
            m) money=$OPTARG ;;
            t) technique=$OPTARG ;;
            n) max_spins=$OPTARG ;;
            d) delay=$OPTARG ;;
            o) output_file=$OPTARG
               [[ -n "$output_file" ]] || { fail 'La ruta del CSV no puede estar vacía.'; return 1; } ;;
            h) helpPanel; return 0 ;;
            :) fail "La opción -$OPTARG necesita un valor."; return 1 ;;
            \?) fail "Opción desconocida: -$OPTARG."; helpPanel; return 1 ;;
        esac
    done
    shift "$((OPTIND - 1))"
    if (($#)); then
        fail 'Hay argumentos inesperados. Consulta la ayuda con -h.'
        return 1
    fi
    if ! is_positive_integer "$money" 1000000000; then
        fail 'Indica con -m un saldo entero de 1 a 1000000000, sin ceros iniciales.'
        return 1
    fi
    case "$technique" in
        martingala|paroli) delay=${delay:-0.2} ;;
        inverseLabouchere) delay=${delay:-1} ;;
        *) fail 'Indica con -t martingala, paroli o inverseLabouchere.'; return 1 ;;
    esac
    is_positive_integer "$max_spins" 1000000 || { fail 'El máximo de tiradas debe estar entre 1 y 1000000.'; return 1; }
    [[ "$delay" =~ ^([0-9](\.[0-9]{1,3})?|10(\.0{1,3})?)$ ]] || {
        fail 'La pausa debe estar entre 0 y 10 segundos, con hasta tres decimales y punto decimal.'
        return 1
    }
    "$technique"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
