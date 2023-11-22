
*Author: Samuel Kofi Tetteh Baah (stettehbaah@worldbank.org)
*Date: 22 November 2023


cd ""  //Insert the path of your folder

/*
This dofile illustrates how to use the pip.ado to access extreme and societal poverty estimates by region. 
*/


// Follow these steps to install the pip.ado 

/*The official and stable version of the pip command is available at the Boston College Statistical Software Components (SSC) archive, by typing 

ssc install pip 

in the command window of Stata. 

In addition, the development version, which includes the latest updates and features, can be found at the World Bank GitHub repository, worldbank/pip.  We highly recommend the use of the development version, even though it is not as stable as the version on SSC. This is because the development version is being updated and improved as bugs and issues are discovered. In order to efficiently download this version from GitHub, we recommend the use of the GitHub Stata command developed by E. F. Haghish. The user may execute the following lines in Stata.

net install github, from ("https://haghish.github.io/github/")
github install worldbank/pip
*/

//////////////////////////////////// Figure 2 /////////////////////////////////////////////

// Load and prepare data 
pip wb, server(qa) clear 
keep region_name year headcount spr 
replace headcount = 100*headcount
replace spr = 100*spr
lab var headcount "Extreme poverty rate (%)"
lab var spr		  "Societal poverty rate (%)"
lab var year	  "Year"

// Sort data data in Excel 
gen sorting_var = 1 if region_name=="World"  // Set "World" as first region
sort sorting_var region_name year

// Clean up data 
drop sorting_var
drop if year<1990

export excel using "SPL-Blog-Data.xlsx", sheet("Figure 2") firstrow(varlabels) sheetreplace

// Visualize data in Flourish



//////////////////////////////////// Figure 3 /////////////////////////////////////////////


// Download data on the World Bank's income classification of countries from here: https://github.com/PovcalNet-Team/Class/tree/master/OutputData
// Save it under the name CLASS.dta

// Load income classification data 
use "CLASS.dta", clear 
keep code year_data incgroup_current incgroup_historical
keep if year_data==2022
rename year_data year 
rename incgroup_current incgroup
rename code country_code

tempfile class 
save `class'


// Load population data from PIP auxiliary table files 
pip tables, table(pop) server(qa) clear
rename data_level reporting_level 
rename value pop 

tempfile pop 
save `pop'

// Load data for survey data coverage
pip tables, table(country_coverage) server(qa) clear  
keep country_code year pop_data_level pop coverage
rename pop_data_level reporting_level 

tempfile cov 
save `cov'

// Load and prepare annual poverty data from PIP
pip, server(qa) clear fillgaps 
keep country_code country_name headcount spr year reporting_level
replace headcount = 100*headcount
replace spr = 100*spr
lab var headcount "Extreme poverty rate (%)"
lab var spr		  "Sociatal poverty rate (%)"
lab var year	  "Year"

// Combine data sets 
merge 1:1 country_code year reporting_level using `pop', gen(pop_merge)
merge 1:1 country_code year reporting_level using `cov', gen(cov_merge)
merge m:1 country_code 			           using `class', gen(class_merge)


keep if !missing(spr) & !missing(headcount)
drop if year<2000

// Create a dummy variable indicating data coverage
gen cov = (coverage=="TRUE") 

// National estimates have no data on coverage; use urban/rural coverage information
egen cov_max = max(cov),by(country_code year) 
replace cov = cov_max if inlist(country_code,"CHN","IND","IDN")  
drop if inlist(country_code,"CHN","IND","IDN") & inlist(reporting_level,"rural","urban")
drop cov_max
tab coverage 
sum 

egen pop_nat_tot = sum(pop) if reporting_level=="national", by(incgroup year)
egen pop_tot = mean(pop_nat_tot), by(incgroup year)

// Generate weight variable
gen pop_weight = pop  

// Generate population with data coverage
replace pop = pop*cov

collapse (mean) spr (mean) headcount (rawsum) pop (mean) pop_tot [aw=pop_weight], by(incgroup year)
gen data_coverage = pop/pop_tot

sort data_coverage
sort incgroup year

// Censor observations without sufficient data coverage
*See this link: https://datanalytics.worldbank.org/PIP-Methodology/lineupestimates.html#coverage
replace spr = . if data_coverage<0.5
replace headcount = . if data_coverage<0.5

// Censor 2021 observations for upper-middle-income high-income countries
*See this link: https://documents.worldbank.org/en/publication/documents-reports/documentdetail/099624209142386941/idu0ac16be61074040439f08b4203f3b4e24fd10
*See this link: https://datanalytics.worldbank.org/PIP-Methodology/lineupestimates.html#coverage
replace spr = . if year==2021 & inlist(incgroup,"High income","Upper middle income") 
replace headcount = . if year==2021 & inlist(incgroup,"High income","Upper middle income") 

// Sort data 
gen sorting_var = 1 if incgroup=="Low income"  
replace sorting_var = 2 if incgroup=="Lower middle income"  
replace sorting_var = 3 if incgroup=="Upper middle income" 
replace sorting_var = 4 if incgroup=="High income" 

sort sorting_var year
drop sorting_var

order incgroup year headcount spr 

lab var headcount "Extreme poverty rate (%)"
lab var spr		  "Societal poverty rate (%)"
lab var year	  "Year"
lab var incgroup  "Income group"

// Clean up data
replace incgroup = "Low-income" if incgroup=="Low income"
replace incgroup = "Lower-middle-income" if incgroup=="Lower middle income"
replace incgroup = "Upper-middle-income" if incgroup=="Upper middle income"
replace incgroup = "High-income" if incgroup=="High income"
keep incgroup year headcount spr 

// Store data in Excel 
export excel using "SPL-Blog-Data.xlsx", sheet("Figure 3") firstrow(varlabels) sheetreplace

// Visualize data in Flourish
