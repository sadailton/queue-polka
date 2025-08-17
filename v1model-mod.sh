#!/bin/bash

input_file="v1model.p4"
v1model_checksum="6f7e8d80db399502ad93bfd6fc2715dd34d98c8abc2b88fefe6cde0281e2dac3"

if [ ! -f $input_file ]; then

	# downloads script
	wget https://raw.githubusercontent.com/p4lang/p4c/main/p4include/v1model.p4 -O $input_file
fi

input_file_checksum=`sha256sum $input_file | cut -d' ' -f1`

if [ $input_file_checksum != $v1model_checksum ]; then
	echo "O arquivo baixado é diferente do que funciona"
	echo $input_file_checksum
	exit 1
fi

# adds the queueing standard_metadata fields

# check if priority needs to be added
if ! grep -q "@alias(\"intrinsic_metadata.priority\")" "$input_file"; then
    # If it doesn't exist, insert it before the closing brace
    sed -i '/struct standard_metadata_t {/,/}/{ 
        /}/i\
    // set packet priority\
    @alias("intrinsic_metadata.priority")\
    bit<3> priority;
    }' "$input_file"
fi

# check if qid needs to be added 
if ! grep -q "@alias(\"queueing_metadata.qid\")" "$input_file"; then
    # If it doesn't exist, insert it before the closing brace
    sed -i '/struct standard_metadata_t {/,/}/{ 
        /}/i\
    // queue used info at egress\
    @alias("queueing_metadata.qid")\
    bit<5> qid;
    }' "$input_file"
fi


# copies it to: /usr/local/share/p4c/p4include/
dst_folder="/usr/local/share/p4c/p4include/"

read -p "Do you want to copy v1model.p4 to $dst_folder? (y/N) " response

if [[ "$response" == "y" || "$response" == "Y" ]]; then
    sudo cp "$input_file" "$dst_folder"
    echo "File copied to $dst_folder"
else
    echo "File v1model.p4 not copied to $dst_folder."
fi
