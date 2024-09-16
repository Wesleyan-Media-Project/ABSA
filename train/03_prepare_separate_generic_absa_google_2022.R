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
path_el_results_with_text <- "../entity_linking_2022/google/data/entity_linking_results_google_2022_notext.csv.gz"

# output from google_2022 repo 
path_ad_text <- "../data_post_production/g2022_adid_01062021_11082022_text.csv.gz"
path_fbel <- "../datasets/google/g2022_train.dta"
path_person <- "../datasets/people/person_2024_cd030124.csv"
path_cands <- "../datasets/candidates/face_url_candidate.csv"
path_pols <- "../datasets/candidates/face_url_politician.csv"
# Intermediary files

# output from data repo
path_intermediary_1 <- "data/intermediate_separate_generic_absa_g2022.rdata" # Note: used as an input in inference
path_intermediary_2 <- "data/intermediate_separate_generic_absa_training_data_g2022.rdata"
# Output files
path_output_train <- "data/generic_separate_absa_gtrain22.csv"
path_output_test <- "data/generic_separate_absa_gtest22.csv"

# Read text in
text <- read_csv(path_ad_text)

text$aws_ocr_text <- ifelse(is.na(text$aws_ocr_img_text) & 
                              is.na(text$aws_ocr_video_text), NA,
                            paste(coalesce(text$aws_ocr_img_text, ""), 
                                  coalesce(text$aws_ocr_video_text, ""),
                                  sep = " "))

text <- text %>% rename(ocr = aws_ocr_text)
text <- text %>% rename(asr = google_asr_text)
text <- text %>% select(-c(ad_url, ad_type, aws_ocr_img_text, 
                           aws_ocr_video_text, filename, checksum))

# Read entity linking results
el_results <- read_csv(path_el_results_with_text)
el_results$field <- gsub("google_asr_text", "asr", el_results$field)
el_results$field <- gsub("aws_ocr_img_text", "ocr", el_results$field)
el_results$field <- gsub("aws_ocr_video_text", "ocr", el_results$field)

el_asr <- el_results %>%
  filter(field == 'asr')

el_asr2 <- el_asr %>%
  pivot_wider(names_from = field,
              id_cols = ad_id,
              values_from = c(text_detected_entities, text_start, text_end),
              names_glue = "{field}_{.value}")

el_results2 <- el_results %>%
  dplyr::filter(field != "asr") %>%
  pivot_wider(names_from = field,
              id_cols = ad_id,
              values_from = c(text_detected_entities, text_start, text_end),
              names_glue = "{field}_{.value}", values_fn = list)

el_results3 <- left_join(el_results2, el_asr2, by = "ad_id")

el_results3$asr_text_detected_entities[is.na(el_results3$asr_text_detected_entities)] <- '[]'
el_results3$asr_text_start[is.na(el_results3$asr_text_start)] <- '[]'
el_results3$asr_text_end[is.na(el_results3$asr_text_end)] <- '[]'

# Combine with text
text2 <- left_join(text, el_results3, by = "ad_id")

# Convert the data of the different fields to long format
# so rows are the ad_id-field level
fields <- names(text2)[2:7]
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
df2 <- df %>%
  dplyr::filter(!is.na(text_start))

save(df2, file = path_intermediary_1)

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
df <- read_dta(path_fbel) %>%
  select(adid,CAND1,CAND2,CAND3,CAND4,CAND5,CAND6,CAND7,CAND8,TONE1,TONE2,TONE3,
         TONE4,TONE5,TONE6,TONE7,TONE8)
df$ad_id <- df$adid

# Fix candidate names from numbers to strings
map <- read.table("../datasets/google/cand_map.txt", header = TRUE, sep = "|", quote = "\"", fill = TRUE)

# Assuming df1 has the CAND columns and df2 has the name and id columns
df1 <- merge(df, map, by.x = "CAND1", by.y = "id", all.x = TRUE)
df1 <- merge(df1, map, by.x = "CAND2", by.y = "id", all.x = TRUE, suffixes = c("", ".CAND2"))
df1 <- merge(df1, map, by.x = "CAND3", by.y = "id", all.x = TRUE, suffixes = c("", ".CAND3"))
df1 <- merge(df1, map, by.x = "CAND4", by.y = "id", all.x = TRUE, suffixes = c("", ".CAND4"))
df1 <- merge(df1, map, by.x = "CAND5", by.y = "id", all.x = TRUE, suffixes = c("", ".CAND5"))
df1 <- merge(df1, map, by.x = "CAND6", by.y = "id", all.x = TRUE, suffixes = c("", ".CAND6"))
df1 <- merge(df1, map, by.x = "CAND7", by.y = "id", all.x = TRUE, suffixes = c("", ".CAND7"))
df1 <- merge(df1, map, by.x = "CAND8", by.y = "id", all.x = TRUE, suffixes = c("", ".CAND8"))

# Rename the columns with appropriate names
df1 <- df1 %>%
  rename(CAND_name1 = name,
         CAND_name2 = name.CAND2,
         CAND_name3 = name.CAND3,
         CAND_name4 = name.CAND4,
         CAND_name5 = name.CAND5,
         CAND_name6 = name.CAND6,
         CAND_name7 = name.CAND7,
         CAND_name8 = name.CAND8)


wmpid <- fread(path_person, data.table = F)



# Define the column names for candidates, tones, and candidate IDs
cand_vars <- paste0("CAND_name", 1:8)
tone_vars <- paste0("TONE", 1:8)
candid_vars <- paste0("CAND_ID", 1:8)

# Select relevant columns from the fecids dataframe
fecids <- select(wmpid, c("wmpid", "full_name"))

# Create the CAND_ID columns and populate them
for(i in 1:length(cand_vars)) {
  # Match candidate names with wmpids full_name and get the corresponding wmpid
  matched_wmpid <- fecids$wmpid[match(as.character(df1[[cand_vars[i]]]), fecids$full_name)]
  
  # Populate the CAND_ID columns in df
  df1[[candid_vars[i]]] <- matched_wmpid
}

# Verify the matching process
cat("Number of rows with at least one matched CAND_ID:", sum(rowSums(!is.na(df1[, candid_vars])) > 0), "\n")

# Select relevant columns and remove rows where all CAND_IDs are NA
df2 <- select(df1, all_of(c(cand_vars, candid_vars, tone_vars, "ad_id")))
df2 <- df1[rowSums(!is.na(df1[, candid_vars])) > 0,]

# Display the number of rows and a few rows of the resulting DataFrame
cat("Number of rows after filtering:", nrow(df2), "\n")

df3 <- df2 %>%
  select(-adid) %>%
  pivot_longer(cols = -ad_id,
               names_to = c(".value", "set"),
               names_pattern = "(\\w+)([0-9])"
  )

df3 <- df3[is.na(df3$CAND_ID) == F,]
df3 <- select(df3, -set)

save(df3, file = path_intermediary_2)

#----
paths <- ls() %>% .[str_detect(., "^path_")]
rm(list = ls()[!ls() %in% paths])

load(path_intermediary_1)
load(path_intermediary_2)


# Combine the entity linking data
# With the FBEL dataset
df4 <- inner_join(df2, df3, by = c("ad_id" = "ad_id", "text_detected_entities" = "CAND_ID"))

# training data
df_train <- df4[is.na(df4$TONE) == F,]

df_train$chunk1 <- substr(df_train$text, 1, df_train$text_start)
df_train$chunk2 <- substr(df_train$text, df_train$text_end+1, nchar(df_train$text))
df_train$text <- paste0(df_train$chunk1, "$T$", df_train$chunk2)

# former contents of prepare_entity_linked_data_for_generic_separate_absa.R
df_train$text <- str_remove_all(df_train$text, "\n")
#df_train <- df_train[df_train$TONE != "",]

####Recode values 1,2,3 to -1,0,1####
df_train$TONE[df_train$TONE == 1] <- 1
df_train$TONE[df_train$TONE == 2] <- -1
df_train$TONE[df_train$TONE == 3] <- 0

# Split

rec_nums <- unique(df_train$ad_id)
set.seed(123)
train <- sample(rec_nums, round(0.7*length(rec_nums)))
test <- rec_nums[!rec_nums %in% train]

train <- df_train[df_train$ad_id %in% train,]
test <- df_train[df_train$ad_id %in% test,]

fwrite(train, path_output_train)
fwrite(test, path_output_test)

