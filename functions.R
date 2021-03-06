#TODO add info about the span of the arrows (i.e.  only shows the last year)

significant_change_calulator <- function(estimate,
                                         confidence_interval,
                                         limit) {
  if (limit == "upper") {
    (estimate - lag(estimate)) 
    + 1.96 * sqrt((confidence_interval / 1.96) ^ 2 
                  + (lag(confidence_interval) / 1.96) ^ 2)
  } else {
    (estimate - lag(estimate)) 
    - 1.96 * sqrt((confidence_interval / 1.96) ^ 2 
                  + (lag(confidence_interval) / 1.96) ^ 2)
  }
}

#################################################################
##                      Sparkline Formats                      ##
#################################################################

# Format for LINE sparklines -----------------------------------------------

sparkline_format <- function(type, y, x, unit, ymax) {
  
  if(type == "line"){
    spk_chr(
      values = y,
      xvalues = x,
      height = "40px",
      width = "100px",
      type = "line",
      numberDigitGroupSep = "",
      # Remove Comma from tooltip
      fillColor = F,
      # Remove shaded area under the line
      lineColor = "#0065bd",
      spotColor = F,
      highlightSpotColor = "#fdd522",
      minSpotColor = F,
      maxSpotColor = F,
      lineWidth = 2,
      #chartRangeMin = 0,
      #chartRangeMax = ymax,
      spotRadius = 3,
      tooltipFormat = paste0('{{x}}: {{y}}', unit))
    
  } else { # Create a bar
    
    spk_chr(
      values = y,
      height = "40px",
      width = 100,
      type = "bar",
      numberDigitGroupSep = "",
      # Remove comma from tooltip
      barColor = "#0065bd",
      negBarColor = "red",
      barWidth = 10,
      barSpacing = 2,
      tooltipFormat = '{{value}}'
    )
  }
}


##################################################################
##                   Create indicator symbols                   ##
##################################################################

# Symbols for Scotland ---------------------------------------------------

create_symbols_scotland <- function(data){
  data %>%
    filter(area == "Scotland") %>%
    group_by(indicator, variable) %>%
    arrange(period) %>%
    filter(!is.na(value)) %>%
    slice_max(period, n = 2) %>%
    arrange(period) %>%
    mutate(change = case_when(value < lag(value) ~ 1,
                              value > lag(value) & value < 0 ~ 0,
                              value > lag(value) & value > 0 ~ 2,
                              value == lag(value) ~ 0)) %>%
    filter(!is.na(change)) %>%
    mutate(icon = case_when(
        change == 1 ~ str_c(icon("arrow-down", lib = "glyphicon"),
                            tags$span(class = "sr-only", "Decrease from last year"),
                            sep = " "),
        change == 2 ~ str_c(icon("arrow-up", lib = "glyphicon"),
                            tags$span(class = "sr-only", "Increase from last year"),
                            sep = " "),
        change == 0 ~ str_c(icon("minus", lib = "glyphicon"),
                            tags$span(class = "sr-only", "No change from last year"),
                            sep = " "))) %>%
    ungroup() %>%
    select(variable, icon)
}

# Symbols for council 1 ---------------------------------------------------

create_symbols_council1 <- function(data, council){
  data %>%
    filter(area %in% council) %>%
    group_by(indicator, variable) %>%
    arrange(desc(period)) %>%
    filter(!is.na(value)) %>%
    slice_max(period, n = 2) %>%
    arrange(period) %>%
    mutate(change = case_when(value < lag(value) ~ 1,
                                     value > lag(value) & value < 0 ~ 0,
                                     value > lag(value) & value > 0 ~ 2,
                                     value == lag(value) ~ 0)) %>%
    filter(!is.na(change)) %>%
    ungroup() %>% 
    mutate(icon1 = case_when(
      change == 1 ~ str_c(icon("arrow-down", lib = "glyphicon"),
                          tags$span(class = "sr-only", "Decrease from last year"),
                          sep = " "),
      change == 2 ~ str_c(icon("arrow-up", lib = "glyphicon"),
                          tags$span(class = "sr-only", "Increase from last year"),
                          sep = " "),
      change == 0 ~ str_c(icon("minus", lib = "glyphicon"),
                          tags$span(class = "sr-only", "No change from last year"),
                          sep = " "))) %>%
    select(variable, icon1)
}

# Symbols for council 2 ---------------------------------------------------

create_symbols_council2 <- function(data, council){
  data %>%
    filter(area %in% council) %>%
    group_by(indicator, variable) %>%
    arrange(desc(period)) %>%
    filter(!is.na(value)) %>%
    slice_max(period, n = 2) %>%
    # Assign the change direction since previous year 
    # Reveresed for Decreased population change 
    arrange(period) %>%
    mutate(change = case_when(value < lag(value) ~ 1,
                              value > lag(value) & value < 0 ~ 0,
                              value > lag(value) & value > 0 ~ 2,
                              value == lag(value) ~ 0)) %>%
    filter(!is.na(change)) %>%
    ungroup() %>%
    mutate(icon2 = case_when(
      change == 1 ~ str_c(icon("arrow-down", lib = "glyphicon"),
                          tags$span(class = "sr-only", "Decrease from last year"),
                          sep = " "),
      change == 2 ~ str_c(icon("arrow-up", lib = "glyphicon"),
                          tags$span(class = "sr-only", "Increase from last year"),
                          sep = " "),
      change == 0 ~ str_c(icon("minus", lib = "glyphicon"),
                          tags$span(class = "sr-only", "No change from last year"),
                          sep = " "))) %>%
    select(variable, icon2)
}
##################################################################
##                   Create HLE/LE indicator symbols            ##
##################################################################
# Life expectancy data is separated because the symbols are based on significant change
# Symbols for Scotland ---------------------------------------------------

create_LE_symbols_scotland <- function(data){
  data %>%
    na.omit() %>%
    filter(area == "Scotland") %>%
    filter(period %in% c(max(period), (max(period)-1))) %>%
    group_by(indicator, variable, area) %>%
    mutate(upper_limit = significant_change_calulator(estimate = value,
                                                      confidence_interval = ci,
                                                      limit = "upper"),
           lower_limit = significant_change_calulator(estimate = value,
                                                      confidence_interval = ci,
                                                      limit = "lower"),
           icon = ifelse(
             # 0 not in positive interval & increased
             lower_limit >= 0 & upper_limit >= 0 & value > lag(value), 1,
             # 0 not in positive interval & decreased
             ifelse(lower_limit >= 0 & upper_limit >= 0 & value < lag(value), -1,
                    # 0 not in negative interval & increased
                    ifelse(lower_limit < 0 & upper_limit < 0 & value > lag(value), 1,
                           # 0 not in negative interval & decreased - everything else maintaining
                           ifelse(lower_limit < 0 & upper_limit < 0 & value < lag(value), -1, 0))))) %>%
    na.omit() %>%
    ungroup() %>%
    mutate(icon = case_when(
      icon == 1 ~ str_c(icon("arrow-up", lib = "glyphicon"),
                        tags$span(class = "sr-only", "Significant increase from last year"),
                        sep = " "),
      icon == 0 ~ str_c(icon("minus", lib = "glyphicon"),
                        tags$span(class = "sr-only", "No significant change from last year"),
                        sep = " "),
      icon == -1 ~ str_c(icon("arrow-down", lib = "glyphicon"),
                         tags$span(class = "sr-only", "Significant decrease from last year"),
                         sep = " "))) %>%
    select(variable, icon)
}

# Symbols for Scotland ---------------------------------------------------

create_LE_symbols_council1 <- function(data, council){
  data %>%
    na.omit() %>%
    filter(area == council) %>%
    filter(period %in% c(max(period), (max(period)-1))) %>%
    group_by(indicator, variable, area) %>%
    mutate(upper_limit = significant_change_calulator(estimate = value,
                                                      confidence_interval = ci,
                                                      limit = "upper"),
           lower_limit = significant_change_calulator(estimate = value,
                                                      confidence_interval = ci,
                                                      limit = "lower"),
           icon1 = ifelse(
             # 0 not in positive interval & increased
             lower_limit >= 0 & upper_limit >= 0 & value > lag(value), 1,
             # 0 not in positive interval & decreased
             ifelse(lower_limit >= 0 & upper_limit >= 0 & value < lag(value), -1,
                    # 0 not in negative interval & increased
                    ifelse(lower_limit < 0 & upper_limit < 0 & value > lag(value), 1,
                           # 0 not in negative interval & decreased - everything else maintaining
                           ifelse(lower_limit < 0 & upper_limit < 0 & value < lag(value), -1, 0))))) %>%
    na.omit() %>%
    ungroup() %>%
    mutate(icon1 = case_when(
      icon1 == 1 ~ str_c(icon("arrow-up", lib = "glyphicon"),
                        tags$span(class = "sr-only", "Significant increase from last year"),
                        sep = " "),
      icon1 == 0 ~ str_c(icon("minus", lib = "glyphicon"),
                        tags$span(class = "sr-only", "No significant change from last year"),
                        sep = " "),
      icon1 == -1 ~ str_c(icon("arrow-down", lib = "glyphicon"),
                         tags$span(class = "sr-only", "Significant decrease from last year"),
                         sep = " "))) %>%
    select(variable, icon1)
}

# Symbols for Scotland ---------------------------------------------------

create_LE_symbols_council2 <- function(data, council){
  data %>%
    na.omit() %>%
    filter(area == council) %>%
    filter(period %in% c(max(period), (max(period)-1))) %>%
    group_by(indicator, variable, area) %>%
    mutate(upper_limit = significant_change_calulator(estimate = value,
                                                      confidence_interval = ci,
                                                      limit = "upper"),
           lower_limit = significant_change_calulator(estimate = value,
                                                      confidence_interval = ci,
                                                      limit = "lower"),
           icon2 = ifelse(
             # 0 not in positive interval & increased
             lower_limit >= 0 & upper_limit >= 0 & value > lag(value), 1,
             # 0 not in positive interval & decreased
             ifelse(lower_limit >= 0 & upper_limit >= 0 & value < lag(value), -1,
                    # 0 not in negative interval & increased
                    ifelse(lower_limit < 0 & upper_limit < 0 & value > lag(value), 1,
                           # 0 not in negative interval & decreased - everything else maintaining
                           ifelse(lower_limit < 0 & upper_limit < 0 & value < lag(value), -1, 0))))) %>%
    na.omit() %>%
    ungroup() %>%
    mutate(icon2 = case_when(
      icon2 == 1 ~ str_c(icon("arrow-up", lib = "glyphicon"),
                        tags$span(class = "sr-only", "Significant increase from last year"),
                        sep = " "),
      icon2 == 0 ~ str_c(icon("minus", lib = "glyphicon"),
                        tags$span(class = "sr-only", "No significant change from last year"),
                        sep = " "),
      icon2 == -1 ~ str_c(icon("arrow-down", lib = "glyphicon"),
                         tags$span(class = "sr-only", "Significant decrease from last year"),
                         sep = " "))) %>%
    select(variable, icon2)
}
##################################################################
##       Create data with sparklines and join the symbols       ##
##################################################################

combine_columns_and_symbols <- function(data, x, y, a, b, c, type, unit, ymax){
  # Take data and create sparkline for just Scotland
  data %>%
  filter(area == "Scotland") %>%
  arrange(period) %>%
  group_by(indicator, variable) %>%
  summarise(
    # Sparkline for Scotland
    "Scotland" = sparkline_format(type, value, period, unit, ymax)) %>%
  # Create and join sparkline for just user input 1
  left_join(
    data %>%
      filter(area %in% x) %>%
      arrange(period) %>%
      group_by(indicator, variable) %>%
      # Sparkline for Council area input 1 (y)
      summarise({{x}} := sparkline_format(type, value, period, unit, ymax))) %>%
  # Create and join sparkline for just user input 2
  left_join(
    data %>%
      filter(area %in% y) %>%
      arrange(period) %>%
      group_by(indicator, variable) %>%
      # Sparkline for Council area input 2 (y)
      summarise({{y}} := sparkline_format(type, value, period, unit, ymax))) %>%
  arrange(match(variable, variable_order)) %>%
  # Join all the symbol columns
  left_join(a) %>%
  relocate(icon, .after = Scotland) %>%
  left_join(b) %>%
  relocate(icon1, .after = 5) %>%
  left_join(c) %>%
  relocate(icon2, .after = 7)
}

# For within scotland - Within Scot separated to deal with absence of council area data
combine_columns_and_symbols_within_scot <- function(data,
                                                    x,y,a,b,c,
                                                    type,
                                                    unit) {
  # Take data and create sparkline for just Scotland
  data %>%
  filter(area == "Scotland") %>%
  arrange(period) %>%
  group_by(indicator, variable) %>%
  summarise(
    # Sparkline for Scotland
    "Scotland" = HTML("")) %>%
  # Create and join sparkline for just user input 1
  left_join(
    data %>%
      filter(area %in% x) %>%
      arrange(period) %>%
      group_by(indicator, variable) %>%
      # Sparkline for Council area input 1 (y)
      summarise({{x}} := sparkline_format(type, value, period, unit))) %>%
  # Create and join sparkline for just user input 2
  left_join(
    data %>%
      filter(area %in% y) %>%
      arrange(period) %>%
      group_by(indicator, variable) %>%
      # Sparkline for Council area input 2 (y)
      summarise({{y}} := sparkline_format(type, value, period, unit))) %>%
  arrange(match(variable, variable_order)) %>%
  # Join all the symbol columns
  left_join(a) %>%
  relocate(icon, .after = Scotland) %>%
  left_join(b) %>%
  relocate(icon1, .after = 5) %>%
  left_join(c) %>%
  relocate(icon2, .after = 7)
}

# Tooltips for the table rows
tooltips <- c(
  "function(row, data, num, index) {",
  # Row 0
        "   if(index === 0) {",
  "    $('td:eq(0)', row).attr('title',
        'Proportion of children, people aged 16-64 and people aged 65 and over.');",
  # Row 3
  "  }else if(index === 3) {",
  "    $('td:eq(0)', row).attr('title',
        'Number of people aged 16 and over that are economically inactive per 1,000 economically active.');",
  # Row 4
  "  }else if(index === 4) {",
  "    $('td:eq(0)', row).attr('title',
        'Average number of years a new born baby could be expected to live. Figures based on 3-year ranges.');",
  # Row 6
  "  }else if(index === 6) {",
  "    $('td:eq(0)', row).attr('title',
        'Average number of years a new born baby could be expected to live in ‘good’ or ‘very good’ health. Figures showing mid-year based on 3-year ranges.');",
  # Row 6
  "  }else if(index === 8) {",
  "    $('td:eq(1)', row).attr('title',
        'The proportion of datazones experiencing population increase');",
  # Row 8
  "  }else if(index === 9) {",
  "    $('td:eq(1)', row).attr('title',
        'The proportion of datazones experiencing population decline.');",
  # Row 9
  "  }else if(index === 10) {",
  "    $('td:eq(1)', row).attr('title',
        'The number of councils experiencing population increase.');",
  # Row 10
  "  }else if(index === 11) {",
  "    $('td:eq(1)', row).attr('title',
        'The number of councils experiencing population decline.');",
  # Row 11
  "  }else if(index === 12) {",
  "    $('td:eq(1)', row).attr('title',
        'Number of births minus deaths');",
  # Row 7
  "  }else if(index === 13) {",
  "    $('td:eq(0)', row).attr('title',
        'Inward minus outward migration');",
  "    $('td:eq(1)', row).attr('title',
        'Net Migration from other areas within Scotland');",
  # Row 12
  "  }else if(index === 14) {",
  "    $('td:eq(1)', row).attr('title',
        'Net migration from the rest of the UK');",
  # Row 13
  "  }else if(index === 15) {",
  "    $('td:eq(1)', row).attr('title',
        'Net migration from outside the UK');",
  # Row 14
  "  }else if(index === 16) {",
  "    $('td:eq(1)', row).attr('title',
        'Net migration from other areas within Scotland and areas outwith Scotland');",
  "  }}")
