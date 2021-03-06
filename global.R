#################################################################
##                          Libraries                          ##
#################################################################

library(shiny)
library(dplyr)
library(sparkline)
library(DT)
library(opendatascot)
library(stringr)

#################################################################
##                          File Paths                         ##
#################################################################
# File paths for static data files
file_path_hle <- "data/HLE.xlsx"
# Net Migration within Scotland
net_within_scot_raw <- readxl::read_excel("data/migflow-ca-01-latest-tab1.xlsx",
                                                  sheet = "TS - Internal Migration",
                                                  range = "B81:U113")
# Net Migration Overseas
net_overseas_raw <- readxl::read_excel("data/mig-overseas-admin-sex-tab1.xlsx",
                                                 sheet = "Net-Council Area-Sex",
                                                 range = "B5:U38") 
# Net Migration - Rest of the UK
net_ruk_raw <- readxl::read_xlsx("data/mig-uk-admin-sex-91-latest-tab2.xlsx",
                             sheet = "Net-Council-Sex (2001-)",
                             range = "A5:U38")
# Components of change
file_path_natural_change <- "data/Natural change - 2009-2020.xlsx"

#################################################################
##                          Variables                          ##
#################################################################

# Area name lookups
area_name_lookup <- read.csv("data/area_codes.csv")

council_areas <- area_name_lookup %>% filter(area != "Scotland")

data_zone_lookup <- read.csv("data/Datazone2011lookup.csv") %>%
  group_by(LA_Name) %>%
  mutate(dz_count = length(unique(DZ2011_Code)))

# Assign endpoint for SPARQL queries
endpoint <- "https://statistics.gov.scot/sparql"

# Get current year for calculating most recent range of data sets
current_year <- lubridate::year(lubridate::today())

# Generate years in quarters for current range.
# e.g. "2009-Q1", "2009-Q2", "2009-Q3", "2009-Q4"
current_quarter <- as.character(zoo::as.yearqtr(lubridate::today())) %>%
  str_sub(start = -2)

year_quarters <- paste0(rep(as.character(c((current_year - 12):(current_year))),
                            each = length(current_quarter)), "-",
                           current_quarter)
# For ordering the table
indicator_order <- c("Population Structure",
                     "Active Dependency Ratio",
                     "Life Expectancy",
                     "Healthy Life Expectancy",
                     "Population Change",
                     "Net Migration")

variables <- c("% Children (under 16 years)",
               "% Working Age (16 - 64)",
               "% Pensionable Age (65 and over)",
               "",
               "Females",
               "Overall",
               "Males",
               "Female",
               "Male",
               "% Increased data zones",
               "% Decreased data zones",
               "Increased council areas",
               "Decreased council areas",
               "Natural Change",
               "Within Scotland",
               "Rest of the UK",
               "Overseas",
               "Total")

variable_order <- c("% Children (under 16 years)",
                    "% Working Age (16 - 64)",
                    "% Pensionable Age (65 and over)",
                    "",
                    "Females",
                    "Males",
                    "Female",
                    "Male",
                    "Natural Change <i class=\"glyphicon glyphicon-info-sign\"></i>",
                    "% Increased data zones <i class=\"glyphicon glyphicon-info-sign\"></i>",
                    "% Decreased data zones <i class=\"glyphicon glyphicon-info-sign\"></i>",
                    "Increased council areas <i class=\"glyphicon glyphicon-info-sign\"></i>",
                    "Decreased council areas <i class=\"glyphicon glyphicon-info-sign\"></i>",
                    "Within Scotland <i class=\"glyphicon glyphicon-info-sign\"></i>",
                    "Rest of the UK <i class=\"glyphicon glyphicon-info-sign\"></i>",
                    "Overseas <i class=\"glyphicon glyphicon-info-sign\"></i>",
                    "Total <i class=\"glyphicon glyphicon-info-sign\"></i>")
  
source("SPARQL_queries.R")
source("functions.R")

##################################################################
##                 Reading & cleaning Raw Data                  ##
##################################################################

##----------------------------------------------------------------
##                     Population Structure                     --
##----------------------------------------------------------------

# Call data with API
pop_structure <- opendatascot:::ods_query_database(endpoint,
                                                   pop_structure_query)

# Population structure by age ---------------------------------------------

pop_structure_age <- pop_structure %>%
  mutate("indicator" = "Population Structure") %>%
  filter(age != "All",
         period >= (current_year - 12)) %>%
  mutate("variable" = paste0("% ", age)) %>%
  select(-c(age, sex))  %>%
  mutate(indicator = paste(
    indicator,
    as.character(icon("info-sign",
                      lib = "glyphicon")))) %>%
  group_by(area, variable, indicator) %>%
  # Fill in any missing years with NA
  tidyr::complete(period = tidyr::full_seq(
    (current_year - 12):(current_year - 1), 1)) %>%
  group_by(area, period) %>%
  mutate(value = round((value / sum(value)) * 100, digits = 2))

# Population Change by Council area -------------------------------

pop_change_by_council_area <- pop_structure %>%
  # Remove scotland and calculate number of decreased population areas
  filter(age == "All",
         area != "Scotland") %>%
  group_by(area) %>%
  arrange(period) %>%
  mutate(change = ifelse(value - lag(value) < 0, 1, 0),
         "variable" = "Decreased council areas") %>%
  # remove 1st lag year
  filter(period >= current_year - 12) %>%
  group_by(period, `variable`) %>%
  # Sum the number of decreased areas for Scotland's total
  summarise(value = sum(change)) %>%
  mutate(area = "Scotland") %>%
  # Repeat for number of increased population areas
  rbind(pop_structure %>%
          filter(age == "All",
                 area != "Scotland") %>%
          group_by(area) %>%
          arrange(period) %>%
          mutate(change = ifelse(value - lag(value) > 0, 1, 0),
                 "variable" = "Increased council areas") %>%
          filter(period >= current_year - 12) %>%
          group_by(period, `variable`) %>%
          # Sum the number of increased areas for Scotland's total
          summarise(value = sum(change)) %>%
          mutate(area = "Scotland")) %>%
  mutate("indicator" = "Population Change")


## ---------------------------------------------------------------
##                   Active Dependency Ratio                   --
## ---------------------------------------------------------------
inactive <- ods_dataset(
  "economic-inactivity",
  measureType = "count",
  gender = "all",
  age = "16-years-and-over",
  refPeriod = year_quarters
)

active <- ods_dataset(
  "economic-activity",
  measureType = "count",
  gender = "all",
  age = "16-years-and-over",
  refPeriod = year_quarters
)

active_dependency_ratio <- inactive %>%
  group_by(refArea, refPeriod) %>%
  summarise(inactivity = as.numeric(value)) %>%
# Join economic ACTIVITY
  inner_join(active %>%
    group_by(refArea, refPeriod) %>%
    summarise(activity = as.numeric(value))) %>%
  # Remove the "-QX" to make it numeric
  mutate(period = as.numeric(gsub("-.*", "", refPeriod)),
         # calculate ADR with inactivity/activity multiplied by 1000
         value = round((inactivity * 1000) / activity, digits = 2),
         "indicator" = "Active Dependency Ratio") %>%
  left_join(area_name_lookup, by = c("refArea" = "area_code")) %>%
  ungroup() %>%
  select(area, period, value, indicator) %>%
  mutate(sex = "",
         age = "",
         "variable" = paste0(age, sex)) %>%
  select(-c(age, sex)) %>%
  mutate(indicator = paste(indicator,
                           as.character(icon("info-sign",
                                             lib = "glyphicon")))) %>%
  group_by(area, variable, indicator) %>%
  tidyr::complete(period = tidyr::full_seq(
    (current_year - 12):(current_year - 1), 1))

## ---------------------------------------------------------------
##                         Life expectancy                      --
## ---------------------------------------------------------------

le <- opendatascot:::ods_query_database(endpoint, le_query) %>%
  left_join(opendatascot:::ods_query_database(endpoint, le_query_ci))

life_expectancy <- le %>%
  mutate("indicator" = "Life Expectancy",
         period = as.numeric(gsub("-.*", "", period))) %>%
  # -13 to include 2019 in mid year from three year range
  filter(period >= (current_year - 13)) %>%
  mutate(value = round(value, digits = 2),
         "variable" = sex,
         # Add one to get middle year of 3 year range
         period = period + 1,
         ci = value - lower_ci) %>%
  select(-c(sex, lower_ci, upper_ci))

## ---------------------------------------------------------------
##                   Healthy life expectancy                    --
## ---------------------------------------------------------------

healthy_life_expectancy <- readxl::read_xlsx(file_path_hle) %>%
  select("area" = Area_name,
         "period" = Period,
         "value" = `Healthy Life Expectancy (HLE) _`,
         "sex" = Sex,
         "lower_ci" = `HLE Lower CI_`,
         "upper_ci" = `HLE Upper CI_`) %>%
  mutate("indicator" = "Healthy Life Expectancy",
         value = round(value, digits = 2),
         "variable" = gsub("s", " ", sex),
         period = (as.numeric(gsub("-.*", "", period)) + 1),
         ci = value - lower_ci) %>%
  select(-c(sex, lower_ci, upper_ci))

## ---------------------------------------------------------------
##               Population Change - Data Zones               --
## ---------------------------------------------------------------
# Call data with API - Too large for one call
pop_estimates_datazones <- opendatascot::ods_dataset(
  "population-estimates-2011-datazone-linked-dataset",
  geography = "dz",
  sex = "all",
  age = "all",
  refPeriod = as.character(c((current_year - 13):(current_year - 10)))
) %>%
  rbind(opendatascot::ods_dataset(
    "population-estimates-2011-datazone-linked-dataset",
    geography = "dz",
    sex = "all",
    age = "all",
    refPeriod = as.character(c((current_year - 9):(current_year - 6)))
  )) %>%
  rbind(opendatascot::ods_dataset(
    "population-estimates-2011-datazone-linked-dataset",
    geography = "dz",
    sex = "all",
    age = "all",
    refPeriod = as.character(c((current_year - 5):current_year)))) %>%
  mutate("indicator" = "Population Change") %>%
  select(-measureType) %>%
  rename("zone" = refArea,
         "period" = refPeriod)


datazone_count <- length(unique(data_zone_lookup$DZ2011_Code))

# Clean data
pop_change_by_data_zone <- pop_estimates_datazones %>%
  # Calculate decreased datazones
  group_by(zone) %>%
  arrange(period) %>%
  mutate(
    value = as.numeric(value),
    period = as.numeric(period),
    change = ifelse(value - lag(value) < 0, 1, 0),
    "variable" = "% Decreased data zones"
  ) %>%
  filter(period != current_year - 13) %>%
  # Add area names
  left_join(data_zone_lookup, by = c("zone" = "DZ2011_Code")) %>%
  rename("area" = LA_Name) %>%
  group_by(area, period, variable, dz_count) %>%
  summarise(value = sum(change)) %>%
  # Calculate Scotland totals and add to data
  rbind(
    pop_estimates_datazones %>%
      group_by(zone) %>%
      arrange(period) %>%
      mutate(
        value = as.numeric(value),
        change = ifelse(value - lag(value) < 0, 1, 0),
        "variable" = "% Decreased data zones"
      ) %>%
      filter(period != current_year - 13) %>%
      group_by(period, variable) %>%
      summarise(value = sum(change)) %>%
      mutate(area = "Scotland",
             "period" = as.numeric(period),
             dz_count = datazone_count)
  ) %>%
  # Calculate and add in increased datazones
  rbind(
    pop_estimates_datazones %>%
      group_by(zone) %>%
      arrange(period) %>%
      mutate(
        value = as.numeric(value),
        period = as.numeric(period),
        change = ifelse(value - lag(value) > 0, 1, 0),
        "variable" = "% Increased data zones"
      ) %>%
      filter(period != current_year - 13) %>%
      # Add area names
      left_join(data_zone_lookup, by = c("zone" = "DZ2011_Code")) %>%
      rename("area" = LA_Name) %>%
      group_by(area, period, variable, dz_count) %>%
      summarise(value = sum(change)) %>%
      # Calculate Scotland totals and add to data
      rbind(
        pop_estimates_datazones %>%
          group_by(zone) %>%
          arrange(period) %>%
          mutate(value = as.numeric(value),
                 change = ifelse(value - lag(value) > 0, 1, 0),
                 variable = "% Increased data zones") %>%
          filter(period != current_year - 13) %>%
          group_by(period, variable) %>%
          summarise(value = sum(change)) %>%
          mutate(area = "Scotland",
                 "period" = as.numeric(period),
                 dz_count = datazone_count))) %>%
  group_by(area, period) %>%
  mutate(value = round((value / dz_count) * 100, digits = 2),
         "indicator" = "Population Change") %>%
  select(-dz_count)

## ---------------------------------------------------------------
##                     Net Within Scotland                     --
## ---------------------------------------------------------------

net_within_scotland <- net_within_scot_raw %>%
  tidyr::pivot_longer(starts_with("20"),
                      names_to = "period",
                      values_to = "value") %>%
  rename("area" = `...1`) %>%
mutate(area = gsub("Total Moves within Scotland3", "Scotland", area),
       "variable" = "Within Scotland",
       "indicator" = "Net Migration",
       period = as.numeric(gsub("-.*", "", period)) + 1,
       variable = paste(variable,
                        as.character(icon("info-sign",
                                          lib = "glyphicon"))),
       indicator = paste(indicator,
                         as.character(icon("info-sign",
                                           lib = "glyphicon")))) %>%
  # Create dummy Scotland for the table to render
  rbind(tibble(area = "Scotland",
               period = current_year - 12,
               value = 0,
               variable = paste("Within Scotland",
                                as.character(icon("info-sign",
                                                  lib = "glyphicon"))),
               indicator = paste("Net Migration",
                                 as.character(icon("info-sign",
                                                   lib = "glyphicon"))))) %>%
  filter(period >= current_year - 12) %>%
  group_by(area, variable, indicator) %>%
  tidyr::complete(period = tidyr::full_seq(
    (current_year - 12):(current_year - 1), 1))

## ----------------------------------------------------------------
##                      Net rest of the UK                      --
## ----------------------------------------------------------------

net_ruk <- net_ruk_raw %>%
  tidyr::pivot_longer(starts_with("20"),
                      names_to = "period",
                      values_to = "value") %>%
  select("area" = `...2`,
         period,
         value) %>%
  mutate("variable" = "Rest of the UK",
         "indicator" = "Net Migration",
         area = gsub("SCOTLAND", "Scotland", area),
         period = as.numeric(gsub("-.*", "", period)) + 1) %>%
  filter(period >= current_year - 12)

## ----------------------------------------------------------------
##                         Net Overseas                         --
## ----------------------------------------------------------------

net_overseas <- net_overseas_raw %>%
  tidyr::pivot_longer(starts_with("20"), 
                      names_to = "period", 
                      values_to = "value") %>%
  select("area" = `...1`,
         period,
         value) %>%
  mutate("variable" = "Overseas",
         "indicator" = "Net Migration",
         area = gsub("SCOTLAND", "Scotland", area),
         # +1 is to pick the later of the year range
         period = as.numeric(gsub("-.*", "", period)) + 1,
         ) %>%
  filter(period >= current_year - 12)

## ----------------------------------------------------------------
##                     Total Net Migration                      --
## ----------------------------------------------------------------

total_net_migration <-
  opendatascot:::ods_query_database(endpoint,
                                    net_migration_query) %>%
  mutate("variable" = "Total",
         "indicator" = "Net Migration") %>%
  select(-c(sex, age))

## ----------------------------------------------------------------
##                     Components of Change                      --
## ----------------------------------------------------------------

natural_change <- readxl::read_excel(file_path_natural_change) %>%
  select(period = Year,
         area = Area,
         value = `Natural Change`)  %>%
  mutate("variable" = "Natural Change",
         "indicator" = "Population Change",
         variable = paste(variable, as.character(icon("info-sign",
                                                      lib = "glyphicon")))) %>%
  group_by(area, variable, indicator) %>%
  tidyr::complete(period = tidyr::full_seq(
    (current_year - 12):(current_year - 1), 1))

##################################################################
##                         Combine Datasets                     ##
##################################################################
  
pop_change_ca <- pop_change_by_council_area %>%
  mutate(variable = paste(variable,
                          as.character(icon("info-sign",
                                            lib = "glyphicon")))) %>%
  group_by(area, variable, indicator) %>%
  tidyr::complete(period = tidyr::full_seq(
    (current_year - 12):(current_year - 1), 1))

pop_change_dz <- pop_change_by_data_zone %>%
  mutate(variable = paste(variable,
                          as.character(icon("info-sign",
                                            lib = "glyphicon")))) %>%
  group_by(area, variable, indicator) %>%
  tidyr::complete(period = tidyr::full_seq(
    (current_year - 12):(current_year - 1), 1))

life_expectancies <- rbind(healthy_life_expectancy,
        life_expectancy) %>%
  mutate(indicator = paste(indicator,
                           as.character(icon("info-sign",
                                             lib = "glyphicon")))) %>%
  group_by(area, variable, indicator) %>%
  tidyr::complete(period = tidyr::full_seq((
    current_year - 12):(current_year - 1), 1))

migration_datasets <-  net_ruk %>%
  rbind(total_net_migration,
        net_overseas) %>%
  mutate(variable = paste(variable,
                          as.character(icon("info-sign",
                                            lib = "glyphicon"))),
         indicator = paste(indicator,
                           as.character(icon("info-sign",
                                             lib = "glyphicon")))) %>%
  group_by(area, variable, indicator) %>%
  tidyr::complete(period = tidyr::full_seq(
    (current_year - 12):(current_year - 1), 1))
