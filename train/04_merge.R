library(tidyverse)

# Input
f20train <- read_csv("data/generic_separate_absa_train20.csv")
f20test <- read_csv("data/generic_separate_absa_test20.csv")
f22train <- read_csv("data/generic_separate_absa_fbtrain22.csv")
f22test <- read_csv("data/generic_separate_absa_fbtest22.csv")
g22train <- read_csv("data/generic_separate_absa_gtrain22.csv") %>%
  select(-CAND_name)
g22test <- read_csv("data/generic_separate_absa_gtest22.csv") %>%
  select(-CAND_name)

# Fix Column Names
f22train <- f22train %>%
  rename(detected_entities = text_detected_entities,
         start = text_start,
         end = text_end)

f22test <- f22test %>%
  rename(detected_entities = text_detected_entities,
         start = text_start,
         end = text_end)

g22train <- g22train %>%
  rename(detected_entities = text_detected_entities,
         start = text_start,
         end = text_end)

g22test <- g22test %>%
  rename(detected_entities = text_detected_entities,
         start = text_start,
         end = text_end)

# Merge All Train/Test Data
colnames(f20train)
colnames(f22train)
colnames(g22train)

df_train <- rbind(f20train, f22train, g22train)
df_test <- rbind(f20test, f22test, g22test)

# Save
write_csv(df_train, "data/generic_separate_absa_train.csv")
write_csv(df_test, "data/generic_separate_absa_test.csv")


