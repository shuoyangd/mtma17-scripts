# Phrase table / lexicon pruning w/ significance based Moses code and custom n-best
# sjmielke@jhu.edu

# Get phrase tables
doit () {
	ln -s /export/b02/huda/experiment/mtma-$3/model/phrase-table.$1.gz phrase-table.$3.$2.gz
}
doit 2 200000 en-de
doit 3 50000  en-de
doit 4 20000  en-de
doit 2 200000 de-en
doit 5 50000  de-en
doit 4 20000  de-en

# Get lexicons (swapping the f2e so its actually f2e!)
doit () {
	dict="/export/b02/huda/experiment/mtma-$3/model/lex.$1.f2e"
	for col in 1 2 3; do
		cut -d ' ' -f $col $dict > tmp.flip$col
	done
	paste -d ' ' tmp.flip{2,1,3} \
		| sed 's/ / ||| /g;s/$/ ||| ||| /' \
		| gzip \
		> lexicon.f2e.swap.$3.$2.gz
	#rm tmp.flip{1,2,3}
}
doit 2 200000 en-de
doit 3 50000  en-de
doit 4 20000  en-de
doit 2 200000 de-en
doit 5 50000  de-en
doit 4 20000  de-en

# Initialize filtering tool
for ts in 20000 50000 200000; do
	for lang in de en; do
		ln -s {/export/b18/mtma17/data/train/,}train.$ts.$lang
		/home/smielke/salm/Bin/Linux/Index/IndexSA.O64 train.$ts.$lang
	done
done

# Prune both w/ significance-based pruning and then manual pruning with n best
n=5
for ts in 20000 50000 200000; do
	doit () {
		src=$1
		trg=$2
		for pmf in lexicon.f2e.swap phrase-table; do
			zcat $pmf.$src-$trg.$ts.gz | /home/smielke/mosesdecoder/contrib/sigtest-filter/filter-pt -e train.$ts.$trg -f train.$ts.$src -l a+e 2> /dev/null | LC_COLLATE=C sort > $pmf.$src-$trg.$ts.pruned-a+e
python3<<EOF
newlines = []
with open("$pmf.$src-$trg.$ts.pruned-a+e", 'r', encoding='utf-8') as f:
        current_source = None
        current_group = []
        for line in f.read().splitlines():
                l = line.split(" ||| ")
                source = l[0]
                target = l[1]
                score = l[2]
                if source == current_source:
                        current_group.append((score, line))
                elif source != current_source:
                        newlines += [l for (s,l) in sorted(current_group, reverse=True)[0:$n]]
                        current_group = []
                        current_source = source
        
        newlines += [l for (s,l) in sorted(current_group, reverse=True)[0:$n]]
with open("$pmf.$src-$trg.$ts.pruned-a+e-n$n", 'w', encoding='utf-8') as f:
        print('\n'.join(newlines), file=f)
EOF

		done
	}
	doit en de
	doit de en
done
