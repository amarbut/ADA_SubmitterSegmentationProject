library(tidyverse)
library(cluster)
library(factoextra)
library(reshape2)
library(tidytext)

#read in tsv of user/form submission pairs for 5000 highest submitting users
#and 5000 highest receiving forms (SQL query in separate file)
top5000 <- read_tsv("top5000.txt")

#create a n_user x n_form matrix with ones for positive user/form submission pairs
#and zeros elsewhere
sparsedf <- top5000%>%
  mutate(dummy = 1)%>%
  distinct%>%
  spread(productid, dummy, fill = 0)

#perform pca on matrix to compress into less sparse form for clustering
pca <- sparsedf%>%
  select(-userid)%>%
  prcomp

#visualize cumulative variance to determine number of components to include
cum_var <- data.frame(sd = pca$sdev)
cum_var <- cum_var%>%
  mutate(eigs = sd^2,
         cum_var = cumsum(eigs/sum(eigs)),
         id = 1:n())

cum_var%>%
  ggplot(aes(x = id, y = cum_var))+
  geom_line()

#find number of components closest to 80% cumulative variance
which.min(abs(cum_var$cum_var-0.80))

##create new df transformed with 959 components instead of 4392
num_pcs = 959

#for each component, compute the dot product of each row/user and the pca rotation
for (i in 1:num_pcs) {
  pc_name <- paste0("PC", i)
  sparsedf[, pc_name] <- as.matrix(sparsedf[,2:4393]) %*% pca$rotation[,i]
}

#select pca columns for clustering
reduced_df <- sparsedf[,-c(1:4393)]

#determine optimal number of clusters for data
#using elbow plot
fviz_nbclust(reduced_df,kmeans, method = "wss", k.max = 20, iter.max = 35)

#using silhouette method
fviz_nbclust(reduced_df, kmeans, method = "silhouette", k.max = 20, iter.max= 35)

#run k-means algorithm with 2, 5, 12, and 16 clusters as potential best fits based on plots
cluster2 <- kmeans(reduced_df, centers = 2, iter.max = 35, nstart = 25)
cluster5 <- kmeans(reduced_df, centers = 5, iter.max = 35, nstart = 25)
cluster12 <- kmeans(reduced_df, centers = 12, iter.max = 35, nstart = 25)
cluster16 <- kmeans(reduced_df, centers = 16, iter.max = 35, nstart = 25)

#visualize total within-cluster ss and between-cluster ss to evaluate models
compare <- data.frame("n_clusters" = c(2, 5, 12, 16),
                      "within_ss" = c(cluster2$tot.withinss, cluster5$tot.withinss, cluster12$tot.withinss, cluster16$tot.withinss),
                      "between_ss" = c(cluster2$betweenss, cluster5$betweenss, cluster12$betweenss, cluster16$betweenss))

compare <- melt(compare, id.vars = 'n_clusters')

compare%>%
  ggplot(aes(x = factor(n_clusters), y = value, fill = variable))+
  geom_col(position = "dodge")+
  labs(title = "Cluster Model Comparison", x = "Number of Clusters",
       y = "Total Sum of Squares", fill = "Metric of Fit")

#text analysis for 5 and 12 clusters to see if they are logical

#pull form ids for each cluster
cluster5_forms <- data.frame("userid" = sparsedf$userid, "cluster" = cluster5$cluster)

cluster5_forms <- cluster5_forms%>%
  left_join(top5000, by = c("userid" = "userid"))%>%
  group_by(cluster)%>%
  count(productid)

cluster12_forms <- data.frame("userid" = sparsedf$userid, "cluster" = cluster12$cluster)

cluster12_forms <- cluster12_forms%>%
  left_join(top5000, by = c("userid" = "userid"))%>%
  group_by(cluster)%>%
  count(productid)

#upload form descriptions (SQL query in separate file) and join with list
form_desc <- readRDS("top5000_formdesc.Rds")

cluster5_text <- cluster5_forms%>%
  left_join(form_desc, by = c("productid" = "productid"))

cluster12_text <- cluster12_forms%>%
  left_join(form_desc, by = c("productid" = "productid"))

#tidy up text for analysis, tokenize, remove punctuation and stop words
cluster5_tidytext <- cluster5_text%>%
  unnest_tokens(word, description, format = "html", strip_punct = TRUE)%>%
  anti_join(stop_words)
  
cluster12_tidytext <- cluster12_text%>%
  unnest_tokens(word, description, format = "html", strip_punct = TRUE)%>%
  anti_join(stop_words)  

#find the 10 most frequent words for each cluster
cluster5_tf <- cluster5_tidytext%>%
  group_by(cluster)%>%
  count(word, sort = TRUE)%>%
  ungroup()

cluster5_tf%>%
  arrange(desc(nn)) %>%
  mutate(word = factor(word, levels = rev(unique(word)))) %>% 
  group_by(cluster) %>%
  top_n(10)%>%
  ungroup %>%
  ggplot(aes(word, nn, fill = factor(cluster))) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "Frequency") +
  facet_wrap(~cluster, ncol = 2, scales = "free") +
  coord_flip()
  
cluster12_tf <- cluster12_tidytext%>%
  group_by(cluster)%>%
  count(word, sort = TRUE)%>%
  ungroup()

# calculate tfidf for clusters

cluster5_tfidf <- cluster5_tf%>%
  bind_tf_idf(word, cluster, nn)

cluster5_tfidf%>%
  arrange(desc(tf_idf)) %>%
  mutate(word = factor(word, levels = rev(unique(word)))) %>% 
  group_by(cluster) %>%
  top_n(10)%>%
  ungroup %>%
  ggplot(aes(word, tf_idf, fill = factor(cluster))) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "Frequency") +
  facet_wrap(~cluster, ncol = 2, scales = "free") +
  coord_flip()

cluster12_tfidf <- cluster12_tf%>%
  bind_tf_idf(word, cluster, nn)

cluster12_tfidf%>%
  arrange(desc(tf_idf)) %>%
  mutate(word = factor(word, levels = rev(unique(word)))) %>% 
  group_by(cluster) %>%
  top_n(10)%>%
  ungroup %>%
  ggplot(aes(word, tf_idf, fill = factor(cluster))) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "Frequency") +
  facet_wrap(~cluster, ncol = 2, scales = "free") +
  coord_flip()
