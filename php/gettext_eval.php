<?php
$str = " 5%10==1 && 5%100!=11 ? 0 : 5%10>=2 && 5%10<=4 && (5%100<10 || 5%100>=20) ? 1 : 2" ;
/*" 5%10==1 && 5%100!=11 ? 0 : 5%10>=2 && 5%10<=4 && (5%100<10 || 5%100>=20) ? 1 : 2"*/
/*"5==0 ? 0 : 5==1 ? 1 : 5==2 ? 2 : 5%100>=3 && n%100<=10 ? 3 : 5%100>=11 ? 4 : 5";*/
$num = 0;
$var = 0;
$stk = array();
$i=0;
$ans = 0;
$k=0;
function push_into_stack($var){
	global $stk;
	if(empty($stk)||$var==="&&"||$var==="||"){
		if($var==true){
			echo "true is pushed\n";
		}
		else if($var==false)
			echo "false is pushed\n";
		else if($var=="&&"){
			echo "&& is pushed\n";
		}
		else echo "|| is pushed\n";
		array_push($stk, $var);
	}
	else if($stk[count($stk)-1]=="&&" || $stk[count($stk)-1]=="||" ){
			switch ($stk[count($stk)-1]) {
				case "&&":
					# code...
					array_pop($stk);
					#echo  "&& is selected";
					$var = $var&&array_pop($stk);
					push_into_stack($var);
					break;
			
				case "||":
					# code...
					#echo "|| is selected";
					array_pop($stk);
					$var = $var||array_pop($stk);
					push_into_stack($var);
					break;
			}
	}
}
/*function next_num($i){
	while(substr($str, $i,1)==' ')
		$i++;
	if(ctype_digit(substr($str,$i,1))){
		$c = $i;
		while(ctype_digit(substr($str,$i,1))){
			$i++;
			$k++;
		}
		$num =  substr($str,$c,$k);
		//required value
		$ans = $num;
		return $num;
	}	
}*/
function nextnum($i){
	global $str,$i;
	$l=0;
	while(!ctype_digit(substr($str,$i,1)))
		$i++;
	if(ctype_digit(substr($str,$i,1))){
		echo "number\n";
		$c = $i;
		while(ctype_digit(substr($str,$i,1))){
			$i++;
			$l++;
		}
		$num =  substr($str,$c,$l);
		//required value
		return $num;
	}	
}
while($i<strlen($str)){
	#skips if blank space occurs
	if(substr($str,$i,1)==' '){
			$i++;
			continue;
	}
	#saves the number if it occurs
	if(ctype_digit(substr($str,$i,1))){
		echo "number\n";
		$c = $i;
		while(ctype_digit(substr($str,$i,1))){
			$i++;
			$k++;
		}
		$num =  substr($str,$c,$k);
		//required value
		$ans = $num;
	}
	#cheking comparison operator
	if(substr($str,$i,1)=="="||substr($str,$i,1)=="<"||substr($str,$i,1)=="!"||substr($str,$i,1)==">"){
		switch(substr($str,$i,1)){
			case "=":
				$i++;
				if(substr($str,$i,1)=="="){
					echo "==\n";
					$var = $num==nextnum($i);
					$ans = $var;
					push_into_stack($var);
				}
				break;
			case "!":
				echo "!=\n";
				$i++;
				$var = $num!=nextnum($i);
				$ans = $var;
				push_into_stack($var);
				break;
			case "<":
				$i++;
				if(ctype_digit(substr($str,$i,1))){
					echo "<\n";
					$var = $num<nextnum($i);
					$ans = $var;
					push_into_stack($var);
				}
				else{
					echo "<=\n";
					$var = $num<=nextnum($i);
					$ans = $var;
					push_into_stack($var);
				}
				break;
			case ">":
				$i++;
				if(ctype_digit(substr($str,$i,1))){
					echo ">\n";
					$var = $num>nextnum($i);
					$ans = $var;
					push_into_stack($var);
				}
				else{
					echo ">=\n";
					$var = $num>=nextnum($i);
					$ans = $var;
					push_into_stack($var);
				}
				break;

			}
		#$i++;
	}
	##case of modulo and div operators
	if(substr($str,$i,1)=="%"||substr($str, $i,1)=="/"){
		switch(substr($str,$i,1)){
			case "%":
				echo "%\n";
				$i++;
				$num = $num%nextnum($i);
				break;
			case "/":
				echo "/\n";
				$i++;
				$num = $num/nextnum($i);
				break;
		}
	}
	#case of ternary operatorys
	if(substr($str,$i,1)=="?"||substr($str, $i,1)==":"){
		switch(substr($str, $i,1)){
			case "?":
				echo "?\n";
				if(array_pop($stk)){
					$ans = nextnum($i);
					echo $ans + " is answer";
					return;
				}
				$i++;
				break;
			case ":":
				echo ":\n";
				$i++;
				continue 2;
		}
	}
	#case of && and ||
	if(substr($str,$i,1)=="&"||substr($str, $i,1)=="|"||substr($str, $i,1)=="("||substr($str, $i,1)==")"){
		switch (substr($str,$i,1)) {
			case "&":
				echo "&&\n";
				$i++;
				array_push($stk, "&&");
				$i++;
				break;
			case "|":
				echo "||\n";
				$i++;
				array_push($stk, "||");
				$i++;
				break;
			case "(":
				echo "(\n";
				$i++;
				array_push($stk, "(");
				break;
			case ")":
				echo ")\n";
				$c = 0;
				while($var!=")"){
					$var = array_pop($stk);
				}
				$var = array_pop($stk);
				push_into_stack($var);
				$i++;
				break;
		}
	}
}
echo $ans
?>
