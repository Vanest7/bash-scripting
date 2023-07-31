#!/bin/bash


#Colours
   greenColour="\e[0;32m\033[1m"
   endColour="\033[0m\e[0m"
   redColour="\e[0;31m\033[1m"
   blueColour="\e[0;34m\033[1m"
   yellowColour="\e[0;33m\033[1m"
   purpleColour="\e[0;35m\033[1m"
   turquoiseColour="\e[0;36m\033[1m"
   grayColour="\e[0;37m\033[1m"

function ctrl_c(){
	echo -e "\n${redColour}[!] Saliendo...${endColour}"
	exit 1
}

trap ctrl_c INT

function helpPanel(){
	echo -e "\n ${yellowColour}[+]${endColour}${grayColour} Uso:${endColour}\n"$
	echo -e "\t ${purpleColour}m)${endColour} ${grayColour} Dinero con el que se desea jugar${endColour}"
	echo -e "\t ${purpleColour}t)${endColour} ${grayColour} Técnica a utilizar [martingala, paroli, inverseLabouchere]${endColour}"
	
}

function martingala(){
	echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Dinero actual:${endColour} ${greenColour}$money€${endColour}"
	echo -ne "${yellowColour}[+] ${endColour}${grayColour}¿Cúanto dinero quieres apostar? -> ${endColour}" && read init_bet
	echo -ne "${yellowColour}[+]${endColour} ${grayColour}¿A qué deseas apostar continuamente (par/impar)? -> ${endColour}" && read even_odd
	echo -ne "${yellowColour}[+]${endColour} ${grayColour}¿Deseas poner límites? s/n -> ${endColour}" && read answer
	if [ "$answer" == "s" ]; then

		echo -ne "${yellowColour}[+]${endColour} ${grayColour}¿Qué porcentaje deseas ganar? -> ${endColour}" && read benefits
		echo -ne "${yellowColour}[+]${endColour} ${grayColour}¿Qué porcentaje estás dispuesto/a a perder? -> ${endColour}" && read losses
		percent_win=$(echo "scale=2; $benefits*1/100" | bc)
		percent_loss=$(echo "scale=2; $losses*1/100" | bc)
		benefits=$(echo "scale=2; $money*$percent_win" | bc)
		losses=$(echo "scale=2; $money*$percent_loss" | bc)
		stop_loss=$(echo "scale=0; $money-$money*$percent_loss/1" | bc)
		stop_win=$(echo "scale=0; $money+$money*$percent_win/1" | bc)
		echo -e  "${yellowColour}[+]${endColour} ${grayColour}Dinero que deseas ganar: ${endColour}${greenColour}$benefits${endColour}"
		echo -e  "${yellowColour}[+]${endColour} ${grayColour}Dinero que estas dispuesto/a a perder: ${endColour}${redColour}$losses${endColour}"
		sleep 3
	fi	
	echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Vamos a jugar con una cantidad inicial de ${endColour}${purpleColour}$init_bet€${endColour} ${grayColour}a${endColour} ${purpleColour}$even_odd${endColour}${grayColour}. Saldo actual: ${endColour}${greenColour}$money${endColour}${grayColour}.${endColour}"
	backup_bet=$init_bet
	declare -i play_counter=1
	while true; do
		money=$(($money-$init_bet))
		random_number="$(($RANDOM % 37))"
		echo -e "\n${yellowColour}[+]${endColour}${grayColour} Saldo actual: ${endColour}${greenColour}$money€${endColour}"
		echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Ha salido el número${endColour} ${blueColour}$random_number${endColour}"
		if [ ! "$money" -le 0 ]; then
			if [ $benefits ] || [ $losses ]; then
				if [ $money -ge $stop_win ]; then						
					echo -e "\n${yellowColour}[+]${endColour} ${greenColour}¡¡Enhorabuena!! has llegado a las ganancias deseadas${endColour}"
					echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Jugadas totales:${endColour}${blueColour} $play_counter${endColour}"
					exit 0
				elif [ $money -le $stop_loss ]; then
					echo -e "\n${redColour}[!] Has alcanzado tu límite de pérdidas, vete a casa !ludopata¡${endColour}"
					echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Jugadas totales: ${endColour}${blueColour}$play_counter${endColour}"
					exit 0
				fi	
			fi
			if [ "$even_odd" == "par" ]; then
				if [ "$(($random_number % 2))" -eq 0 ] && [ "$random_number" -ne 0 ]; then
					reward=$(($init_bet*2))
					money=$(($money+$reward))
					init_bet=$backup_bet
					echo -e "${yellowColour}[+]${endColour} ${greenColour}¡Ganas $reward€!${endColour}"
					echo -e "${yellowColour}[+]${endColour} Saldo:${greenColour}$money€${endColour}"
				else
					echo -e "${yellowColour}[+] ${endColour}${redColour}Pierdes${endColour}"
					init_bet=$(($init_bet*2))
					echo -e "\n${yellowColour}[+]${endColour} ${grayColour}La apuesta sube a: ${endColour}${greenColour}$init_bet€${endColour}"	
				fi	
					sleep 0.2
					play_counter+=1
			elif [ "$even_odd" == "impar" ]; then
				if [ "$(($random_number % 2))" -ne 0 ] && [ "$random_number" -ne 0 ]; then
                                        reward=$(($init_bet*2))
                                        money=$(($money+$reward))
                                        init_bet=$backup_bet
                                        echo -e "${yellowColour}[+]${endColour} ${greenColour}¡Ganas $reward€!${endColour}"
                                        echo -e "${yellowColour}[+]${endColour} Saldo:${greenColour}$money€${endColour}"
                                else
                                        echo -e "${yellowColour}[+] ${endColour}${redColour}Pierdes${endColour}"
                                        init_bet=$(($init_bet*2))
                                        echo -e "\n${yellowColour}[+]${endColour} ${grayColour}La apuesta sube a: ${endColour}${greenColour}$init_bet€${endColour}"             
                                fi      
                                        sleep 0.2
					play_counter+=1
			fi		
		else
			echo -e "${redColour}[!] Te has quedado sin pasta!! Adiós${endColour}"
			echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Jugadas totales:${endColour}${blueColour} $play_counter${endColour}"
			exit 0

				
			fi
	done
		
}


function paroli(){
	echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Dinero actual:${endColour} ${greenColour}$money€${endColour}"
	echo -ne "${yellowColour}[+] ${endColour}${grayColour}¿Cúanto dinero quieres apostar? -> ${endColour}" && read init_bet
	echo -ne "${yellowColour}[+]${endColour} ${grayColour}¿A qué deseas apostar continuamente (par/impar)? -> ${endColour}" && read even_odd
	echo -ne "${yellowColour}[+]${endColour} ${grayColour}¿Deseas poner límites? s/n -> ${endColour}" && read answer
	if [ "$answer" == "s" ]; then

		echo -ne "${yellowColour}[+]${endColour} ${grayColour}¿Qué porcentaje deseas ganar? -> ${endColour}" && read benefits
		echo -ne "${yellowColour}[+]${endColour} ${grayColour}¿Qué porcentaje estás dispuesto/a a perder? -> ${endColour}" && read losses
		percent_win=$(echo "scale=2; $benefits*1/100" | bc)
		percent_loss=$(echo "scale=2; $losses*1/100" | bc)
		benefits=$(echo "scale=2; $money*$percent_win" | bc)
		losses=$(echo "scale=2; $money*$percent_loss" | bc)
		stop_loss=$(echo "scale=0; $money-$money*$percent_loss/1" | bc)
		stop_win=$(echo "scale=0; $money+$money*$percent_win/1" | bc)
		echo -e  "${yellowColour}[+]${endColour} ${grayColour}Dinero que deseas ganar: ${endColour}${greenColour}$benefits${endColour}"
		echo -e  "${yellowColour}[+]${endColour} ${grayColour}Dinero que estas dispuesto/a a perder: ${endColour}${redColour}$losses${endColour}"
		sleep 3
	fi	
	echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Vamos a jugar con una cantidad inicial de ${endColour}${purpleColour}$init_bet€${endColour} ${grayColour}a${endColour} ${purpleColour}$even_odd${endColour}${grayColour}. Saldo actual: ${endColour}${greenColour}$money${endColour}${grayColour}.${endColour}"
	backup_bet=$init_bet
	declare -i play_counter=1
	while true; do
		money=$(($money-$init_bet))
		random_number="$(($RANDOM % 37))"
		echo -e "\n${yellowColour}[+]${endColour}${grayColour} Saldo actual: ${endColour}${greenColour}$money€${endColour}"
		echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Ha salido el número${endColour} ${blueColour}$random_number${endColour}"
		if [ ! "$money" -le 0 ]; then
			if [ $benefits ] || [ $losses ]; then
				if [ $money -ge $stop_win ]; then						
					echo -e "\n${yellowColour}[+]${endColour} ${greenColour}¡¡Enhorabuena!! has llegado a las ganancias deseadas${endColour}"
					echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Jugadas totales:${endColour}${blueColour} $play_counter${endColour}"
					exit 0
				elif [ $money -le $stop_loss ]; then
					echo -e "\n${redColour}[!] Has alcanzado tu límite de pérdidas, vete a casa !ludopata¡${endColour}"
					echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Jugadas totales: ${endColour}${blueColour}$play_counter${endColour}"
					exit 0
				fi	
			fi
			if [ "$even_odd" == "par" ]; then
				if [ "$(($random_number % 2))" -eq 0 ] && [ "$random_number" -ne 0 ]; then
					reward=$(($init_bet*2))
					money=$(($money+$reward))
					init_bet=$(($init_bet*2))
					echo -e "${yellowColour}[+]${endColour} ${greenColour}¡Ganas $reward€!${endColour}"
					echo -e "${yellowColour}[+]${endColour} Saldo:${greenColour}$money€${endColour}"
					echo -e "\n${yellowColour}[+]${endColour} ${grayColour}La apuesta sube a: ${endColour}${greenColour}$init_bet€${endColour}"	
				else
					echo -e "${yellowColour}[+] ${endColour}${redColour}Pierdes${endColour}"
					init_bet=$backup_bet
				
				fi	
					sleep 0.2
					play_counter+=1
			elif [ "$even_odd" == "impar" ]; then
				if [ "$(($random_number % 2))" -ne 0 ] && [ "$random_number" -ne 0 ]; then
                                        reward=$(($init_bet*2))
                                        money=$(($money+$reward))
                                        init_bet=$(($init_bet*2))
                                        echo -e "${yellowColour}[+]${endColour} ${greenColour}¡Ganas $reward€!${endColour}"
                                        echo -e "\n${yellowColour}[+]${endColour} ${grayColour}La apuesta sube a: ${endColour}${greenColour}$init_bet€${endColour}"             
                                        echo -e "${yellowColour}[+]${endColour} Saldo:${greenColour}$money€${endColour}"
                                else
                                        echo -e "${yellowColour}[+] ${endColour}${redColour}Pierdes${endColour}"
                                        init_bet=$backup_bet
                                fi      
                                        sleep 0.2
					play_counter+=1
			fi		
		else
			echo -e "${redColour}[!] Te has quedado sin pasta!! Adiós${endColour}"
			echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Jugadas totales:${endColour}${blueColour} $play_counter${endColour}"
			exit 0

				
			fi
	done
		
}

function inverseLabouchere(){
	echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Dinero actual:${endColour} ${greenColour}$money€${endColour}"
        echo -ne "${yellowColour}[+]${endColour} ${grayColour}¿A qué deseas apostar continuamente (par/impar)? -> ${endColour}" && read even_odd

	declare -a my_sequence=(1 2 3 4)
	declare -i play_counter=1
	echo -e "\n${yellowColour}[+]${endColour}${grayColour}Comenzamos con la secuencia ${endColour}${blueColour}[${my_sequence[@]}]${endColour}"
	bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
	bet_to_renew=$(($money+50))
	while true; do
		play_counter+=1
		random_number="$(($RANDOM % 37))"
		money=$(($money - $bet))
		if [ "$money" -gt 0 ]; then
			echo -e "\n${yellowColour}[+]${endColour}${grayColour}Apostamos ${endColour}${greenColour}$bet€${endColour}"
			echo -e "\n${yellowColour}[+]${endColour}${grayColour} Saldo actual: ${endColour}${greenColour}$money€${endColour}"
			echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Ha salido el número${endColour} ${blueColour}$random_number${endColour}"

			if [ "$even_odd" == "par" ]; then
				if [ "$(($random_number % 2))" -eq 0 ] && [ "$random_number" -ne 0 ]; then
					reward=$(($bet*2))
					money=$(($money+$reward))
					echo -e "${yellowColour}[+]${endColour} ${greenColour}¡Ganas $reward€!${endColour}"
					echo -e "${yellowColour}[+]${endColour} Saldo:${greenColour}$money€${endColour}"
					if [ "$money" -gt $bet_to_renew ]; then
						my_sequence=(1 2 3 4)
						bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
						echo -e "${yellowColour}[+]${endColour}${grayColour} Se ha superado el limite de ganancias establecido en ${endColour}${greenColour}$bet_to_renew${endColour}${grayColour}, restableciendo la secuencia a ${endColour}${blueColour}[${my_sequence[@]}]${endColour}"
						bet_to_renew=$(($bet_to_renew + 50))
					elif [ $money -lt $(($bet_to_renew - 100)) ]; then
						 bet_to_renew=$(($bet_to_renew - 100))
					else
						my_sequence+=($bet)
						my_sequence=(${my_sequence[@]})
					fi
					echo -e "${yellowColour}[+]${endColour} ${grayColour}La nueva secuencia es: ${endColour}${blueColour} [${my_sequence[@]}]${endColour}"
					if [ "${#my_sequence[@]}" -ne 1 ] && [  "${#my_sequence[@]}" -ne 0 ]; then
						bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
					elif [ "${#my_sequence[@]}" -eq 1 ]; then
						bet=${my_sequence[0]}
					else
						my_sequence=(1 2 3 4)
						echo -e "${redColour}[!] Hemos perdido nuestra secuencia${endColour}"
						echo -e "${yellowColour}[+]${endColour}${grayColour} Restableciendo la secuencia a: ${endColour}${blueColour} [${my_sequence[@]}] ${endColour}"
					 bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
					fi
				elif [ "$((random_number % 2))" -eq 1 ] || [ "$random_number" -eq 0 ]; then
					echo -e "${redColour}[!] Pierdes${endColour}"
					unset my_sequence[0]
					unset my_sequence[-1] 2>/dev/null
					my_sequence=(${my_sequence[@]})
					echo -e "${yellowColour}[+]${endColour} ${grayColour}La nueva secuencia es: ${endColour}${blueColour} [${my_sequence[@]}]${endColour}"
					if [ "${#my_sequence[@]}" -ne 1 ] && [  "${#my_sequence[@]}" -ne 0 ]; then
						bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
					elif [ "${#my_sequence[@]}" -eq 1 ]; then
						bet=${my_sequence[0]}
					else
						my_sequence=(1 2 3 4)
						echo -e "${redColour}[!] Hemos perdido nuestra secuencia${endColour}"
						echo -e "${yellowColour}[+]${endColour}${grayColour} Restableciendo la secuencia a: ${endColour}${blueColour}[${my_sequence[@]}]${endColour}"
						bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
					fi
				fi
			
			elif [ "$even_odd" == "impar" ]; then
				if [ "$(($random_number % 2))" -eq 1 ] && [ "$random_number" -ne 0 ]; then
					reward=$(($bet*2))
					money=$(($money+$reward))
					echo -e "${yellowColour}[+]${endColour} ${greenColour}¡Ganas $reward€!${endColour}"
					echo -e "${yellowColour}[+]${endColour} Saldo:${greenColour}$money€${endColour}"
					if [ "$money" -gt $bet_to_renew ]; then
						my_sequence=(1 2 3 4)
						bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
						echo -e "${yellowColour}[+]${endColour}${grayColour} Se ha superado el limite de ganancias establecido en ${endColour}${greenColour}$bet_to_renew${endColour}${grayColour}, restableciendo la secuencia a ${endColour}${blueColour}[${my_sequence[@]}]${endColour}"
						bet_to_renew=$(($bet_to_renew + 50))
					elif [ $money -lt $(($bet_to_renew - 100)) ]; then
						 bet_to_renew=$(($bet_to_renew - 100))
					else
						my_sequence+=($bet)
						my_sequence=(${my_sequence[@]})
					fi
					echo -e "${yellowColour}[+]${endColour} ${grayColour}La nueva secuencia es: ${endColour}${blueColour} [${my_sequence[@]}]${endColour}"
					if [ "${#my_sequence[@]}" -ne 1 ] && [  "${#my_sequence[@]}" -ne 0 ]; then
						bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
					elif [ "${#my_sequence[@]}" -eq 1 ]; then
						bet=${my_sequence[0]}
					else
						my_sequence=(1 2 3 4)
						echo -e "${redColour}[!] Hemos perdido nuestra secuencia${endColour}"
			echo -e "${yellowColour}[+]${endColour}${grayColour} Restableciendo la secuencia a: ${endColour}${blueColour} [${my_sequence[@]}] ${endColour}"
					 bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
					fi
				elif [ "$((random_number % 2))" -eq 0 ] || [ "$random_number" -eq 0 ]; then
					echo -e "${redColour}[!] Pierdes${endColour}"
					
					unset my_sequence[0]
					unset my_sequence[-1] 2>/dev/null

					my_sequence=(${my_sequence[@]})
					echo -e "${yellowColour}[+]${endColour} ${grayColour}La nueva secuencia es: ${endColour}${blueColour} [${my_sequence[@]}]${endColour}"
					if [ "${#my_sequence[@]}" -ne 1 ] && [  "${#my_sequence[@]}" -ne 0 ]; then
						bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
					elif [ "${#my_sequence[@]}" -eq 1 ]; then
						bet=${my_sequence[0]}
					else
						my_sequence=(1 2 3 4)
						echo -e "${redColour}[!] Hemos perdido nuestra secuencia${endColour}"
						echo -e "${yellowColour}[+]${endColour}${grayColour} Restableciendo la secuencia a: ${endColour}${blueColour}[${my_sequence[@]}]${endColour}"
						bet=$((${my_sequence[0]} + ${my_sequence[-1]}))
					fi
fi
			fi
	
		else
			echo -e "${redColour}[!] Te has quedado sin pasta!! Adiós${endColour}"
			echo -e "\n${yellowColour}[+]${endColour} ${grayColour}Jugadas totales:${endColour}${blueColour} $play_counter${endColour}"
			exit 0
		fi
		sleep 1	
	done	
}

while getopts "m:t:h" arg; do
	case $arg in 
		m) money=$OPTARG;;
		t) technique=$OPTARG;;
		h);;
	esac	
done	

if [ $money ] && [ $technique ]; then 
	if [ "$technique" == "martingala" ]; then 
		martingala
	elif [ "$technique" == "paroli" ]; then
		paroli
	elif [ "$technique" == "inverseLabouchere" ]; then
		inverseLabouchere
	else
		helpPanel
	fi	
else 
	helpPanel
fi
