library(stringr)
library(dplyr)
library(readr)
library(tidyr)
library(stringi)
library(data.table)
library(tidyverse)
library(haven)
library(readxl)

# Input files
path_el_results_with_text <- "../entity_linking_2022/facebook/data/entity_linking_results_fb22_notext.csv.gz"

# output from fb_2022 repo 
path_ad_text <- "../data_post_production/fb_2022_adid_text.csv.gz"
path_fbel <- "../datasets/facebook/fb_2022_train.xlsx"
path_person <- "../datasets/people/person_2024_cd030124.csv"
path_cands <- "../datasets/candidates/face_url_candidate.csv"
path_pols <- "../datasets/candidates/face_url_politician.csv"
# Intermediary files

# output from data repo
path_intermediary_1 <- "data/intermediate_separate_generic_absa_fb2022.rdata" #
path_intermediary_2 <- "data/intermediate_separate_generic_absa_training_data_fb2022.rdata"
# Output files
path_output_train <- "data/generic_separate_absa_fbtrain22.csv"
path_output_test <- "data/generic_separate_absa_fbtest22.csv"

# Read text in
text <- read_csv(path_ad_text)

text$aws_ocr_text <- ifelse(is.na(text$aws_ocr_text_img) & 
                              is.na(text$aws_ocr_text_vid), NA,
                            paste(coalesce(text$aws_ocr_text_img, ""), 
                                  coalesce(text$aws_ocr_text_vid, ""),
                                  sep = " "))

text <- text %>% rename(ocr = aws_ocr_text)
text <- text %>% rename(asr = google_asr_text)
text <- text %>% select(-c(ad_snapshot_url, ad_creative_bodies, ad_creative_bodies,
                           ad_creative_link_titles, ad_creative_link_descriptions,
                           aws_ocr_text_img, aws_ocr_text_vid, aws_status_img,
                           aws_status_vid, product_brand, product_name, 
                           product_description, ad_creative_link_captions,
                           google_asr_status))

# Read entity linking results
el_results <- read_csv(path_el_results_with_text)
el_results$field <- gsub("google_asr_text", "asr", el_results$field)
el_results$field <- gsub("aws_ocr_text_img", "ocr", el_results$field)
el_results$field <- gsub("aws_ocr_text_vid", "ocr", el_results$field)

el_asr <- el_results %>%
  filter(field == 'asr')

el_asr2 <- el_asr %>%
  pivot_wider(names_from = field,
              id_cols = ad_id,
              values_from = c(text_detected_entities, text_start, text_end),
              names_glue = "{field}_{.value}")

el_results2 <- el_results %>%
  filter(field != "asr") %>%
  pivot_wider(names_from = field,
              id_cols = ad_id,
              values_from = c(text_detected_entities, text_start, text_end),
              names_glue = "{field}_{.value}")

el_results3 <- left_join(el_results2, el_asr2, by = "ad_id")

el_results3$asr_text_detected_entities[is.na(el_results3$asr_text_detected_entities)] <- '[]'
el_results3$asr_text_start[is.na(el_results3$asr_text_start)] <- '[]'
el_results3$asr_text_end[is.na(el_results3$asr_text_end)] <- '[]'

# Combine with text
text2 <- left_join(text, el_results3, by = "ad_id")

# Convert the data of the different fields to long format
# so rows are the ad_id-field level
fields <- names(text2)[2:9]
variations <- c("", "_text_detected_entities", "_text_start", "_text_end")
out <- list()
for(i in 1:length(fields)){
  text3 <- text2[c("ad_id", paste0(fields[i], variations))]
  names(text3) <- c("ad_id", "text", "text_detected_entities", "text_start", "text_end")
  text3$field <- fields[i]
  out[[i]] <- text3
}

df <- rbindlist(out)
df <- df[df$text_detected_entities != "[]",]


# Ensure the columns are character vectors before processing
df$text_start <- as.character(df$text_start)
df$text_end <- as.character(df$text_end)
df$text_detected_entities <- as.character(df$text_detected_entities)

# Function to convert a Python-style list string into an R list
python_to_r_list <- function(x) {
  lapply(strsplit(gsub("\\[|\\]|'", "", x), ",\\s*"), function(y) y)
}

# Apply the function to the relevant columns
df$text_detected_entities <- python_to_r_list(as.character(df$text_detected_entities))
df$text_start <- python_to_r_list(as.character(df$text_start))
df$text_end <- python_to_r_list(as.character(df$text_end))


# Unnest to create one row per detected entity
df <- df %>% unnest(cols = c(text_detected_entities, text_start, text_end))

# Convert numeric columns if needed
df$text_start <- as.numeric(df$text_start)
df$text_end <- as.numeric(df$text_end)

save(df, file = path_intermediary_1)

#----
# End of the part that's shared with creating the inference set

# Remove everything except the paths
paths <- ls() %>% .[str_detect(., "^path_")]
rm(list = ls()[!ls() %in% paths])

#df[df == "In a way to show approval or support"] <- 1
#df[df == "In a way to show disaproval or opposition"] <- 2
#df[df == "Unclear whether support or opposition"] <- 3


####Create Training Data####
# Load the dataset
df <- read_excel(path_fbel)
df$ad_id <- df$adid
wmpid <- fread(path_person, data.table = F)

# Define the column names for candidates, tones, and candidate IDs
cand_vars <- paste0("CAND", 1:8)
tone_vars <- paste0("TONE", 1:8)
candid_vars <- paste0("CAND_ID", 1:8)

# Select relevant columns from the fecids dataframe
fecids <- select(wmpid, c("wmpid", "full_name"))

# Create the CAND_ID columns and populate them
for(i in 1:length(cand_vars)) {
  # Match candidate names with fecids full_name and get the corresponding wmpid
  matched_wmpid <- fecids$wmpid[match(as.character(df[[cand_vars[i]]]), fecids$full_name)]
  
  # Populate the CAND_ID columns in df
  df[[candid_vars[i]]] <- matched_wmpid
}

# Verify the matching process
cat("Number of rows with at least one matched CAND_ID:", sum(rowSums(!is.na(df[, candid_vars])) > 0), "\n")

# Select relevant columns and remove rows where all CAND_IDs are NA
df <- select(df, all_of(c(cand_vars, candid_vars, tone_vars, "ad_id")))
df <- df[rowSums(!is.na(df[, candid_vars])) > 0,]

# Display the number of rows and a few rows of the resulting DataFrame
cat("Number of rows after filtering:", nrow(df), "\n")

df2 <- df %>%
  pivot_longer(cols = -ad_id,
               names_to = c(".value", "set"),
               names_pattern = "(\\w+)([0-9])"
  )

df2 <- df2[is.na(df2$CAND_ID) == F,]
df2 <- select(df2, -set)

save(df2, file = path_intermediary_2)


#----
paths <- ls() %>% .[str_detect(., "^path_")]
rm(list = ls()[!ls() %in% paths])

load(path_intermediary_1)
load(path_intermediary_2)


# Combine the entity linking data
# With the FBEL dataset
df3 <- inner_join(df, df2, by = c("ad_id" = "ad_id", "text_detected_entities" = "CAND_ID"))

# training data
df_train <- df3[is.na(df3$TONE) == F,]

df_train$chunk1 <- substr(df_train$text, 1, df_train$text_start)
df_train$chunk2 <- substr(df_train$text, df_train$text_end+1, nchar(df_train$text))
df_train$text <- paste0(df_train$chunk1, "$T$", df_train$chunk2)

# former contents of prepare_entity_linked_data_for_generic_separate_absa.R
df_train$text <- str_remove_all(df_train$text, "\n")
#df_train <- df_train[df_train$TONE != "",]

####Recode values 1,2,3 to -1,0,1####
df_train$TONE[df_train$TONE == "In a way to show approval or support"] <- 1
df_train$TONE[df_train$TONE == "In a way to show disaproval or opposition"] <- -1
df_train$TONE[df_train$TONE == "Unclear whether support or opposition"] <- 0

# Split

rec_nums <- unique(df_train$ad_id)
set.seed(123)
train <- sample(rec_nums, round(0.7*length(rec_nums)))
test <- rec_nums[!rec_nums %in% train]

train <- df_train[df_train$ad_id %in% train,]
test <- df_train[df_train$ad_id %in% test,]

fwrite(train, path_output_train)
fwrite(test, path_output_test)

